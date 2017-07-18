from synchronizers.new_base.modelaccessor import *
from synchronizers.new_base.model_policies.model_policy_tenantwithcontainer import TenantWithContainerPolicy, LeastLoadedNodeScheduler
from synchronizers.new_base.exceptions import *

class VSGTenantPolicy(TenantWithContainerPolicy):
    model_name = "VSGTenant"

    def handle_create(self, tenant):
        return self.handle_update(tenant)

    def handle_update(self, tenant):
        self.manage_container(tenant)
        self.manage_vrouter(tenant)
        self.cleanup_orphans(tenant)

    def handle_delete(self, tenant):
        if tenant.vrouter:
            tenant.vrouter.delete()

    def manage_vrouter(self, tenant):
        if tenant.deleted:
            return

        if tenant.vrouter is None:
            vrouter = self.allocate_public_service_instance(address_pool_name="addresses_vsg", subscriber_tenant=tenant)
            vrouter.save()

    def cleanup_orphans(self, tenant):
        # ensure vSG only has one vRouter
        cur_vrouter = tenant.vrouter
        for link in tenant.subscribed_links.all():
            # TODO: hardcoded dependency
            # cast from ServiceInstance to VRouterTenant
            vrouters = VRouterTenant.objects.filter(id = link.provider_service_instance.id)
            for vrouter in vrouters:
                if (not cur_vrouter) or (vrouter.id != cur_vrouter.id):
                    # print "XXX clean up orphaned vrouter", vrouter
                    vrouter.delete()

    def get_vsg_service(self, tenant):
        return VSGService.objects.get(id=tenant.owner.id)

    def find_instance_for_s_tag(self, s_tag):
        tags = Tag.objects.filter(name="s_tag", value=s_tag)
        if tags:
            return tags[0].content_object

        return None

    def find_or_make_instance_for_s_tag(self, tenant, s_tag):
        instance = self.find_instance_for_s_tag(tenant.volt.s_tag)
        if instance:
            if instance.no_sync:
                # if no_sync is still set, then perhaps we failed while saving it and need to retry.
                self.save_instance(tenant, instance)
            return instance

        desired_image = self.get_image(tenant)

        flavors = Flavor.objects.filter(name="m1.small")
        if not flavors:
            raise SynchronizerConfigurationError("No m1.small flavor")

        slice = tenant.owner.slices.first()

        (node, parent) = LeastLoadedNodeScheduler(slice, label=self.get_vsg_service(tenant).node_label).pick()

        assert (slice is not None)
        assert (node is not None)
        assert (desired_image is not None)
        assert (tenant.creator is not None)
        assert (node.site_deployment.deployment is not None)
        assert (desired_image is not None)

        instance = Instance(slice=slice,
                            node=node,
                            image=desired_image,
                            creator=tenant.creator,
                            deployment=node.site_deployment.deployment,
                            flavor=flavors[0],
                            isolation=slice.default_isolation,
                            parent=parent)

        self.save_instance(tenant, instance)

        return instance

    def manage_container(self, tenant):
        if tenant.deleted:
            return

        if not tenant.volt:
            raise SynchronizerConfigurationError("This VSG container has no volt")

        if tenant.instance:
            # We're good.
            return

        instance = self.find_or_make_instance_for_s_tag(tenant, tenant.volt.s_tag)
        tenant.instance = instance
        # TODO: possible for partial failure here?
        tenant.save()

    def find_or_make_port(self, instance, network, **kwargs):
        port = Port.objects.filter(instance_id=instance.id, network_id=network.id)
        if port:
            port = port[0]
        else:
            port = Port(instance=instance, network=network, **kwargs)
            port.save()
        return port

    def get_lan_network(self, tenant, instance):
        slice = tenant.owner.slices.all()[0]
        # there should only be one network private network, and its template should not be the management template
        lan_networks = [x for x in slice.networks.all() if
                        x.template.visibility == "private" and (not "management" in x.template.name)]
        if len(lan_networks) > 1:
            raise SynchronizerProgrammingError("The vSG slice should only have one non-management private network")
        if not lan_networks:
            raise SynchronizerProgrammingError("No lan_network")
        return lan_networks[0]

    def port_set_parameter(self, port, name, value):
        pt = NetworkParameterType.objects.get(name=name)
        existing_params = NetworkParameter.objects.filter(parameter_id=pt.id, content_type=port.self_content_type_id, object_id=port.id)

        if existing_params:
            p = existing_params[0]
            p.value = str(value)
            p.save()
        else:
            p = NetworkParameter(parameter=pt, content_type=port.self_content_type_id, object_id=port.id, value=str(value))
            p.save()

    def save_instance(self, tenant, instance):
        instance.volumes = "/etc/dnsmasq.d,/etc/ufw"
        instance.no_sync = True   # prevent instance from being synced until we're done with it
        super(VSGTenantPolicy, self).save_instance(instance)
        try:
            if instance.isolation in ["container", "container_vm"]:
                raise Exception("Not supported")

            if instance.isolation in ["vm"]:
                lan_network = self.get_lan_network(tenant, instance)
                port = self.find_or_make_port(instance, lan_network)
                self.port_set_parameter(port, "c_tag", tenant.volt.c_tag)
                self.port_set_parameter(port, "s_tag", tenant.volt.s_tag)
                self.port_set_parameter(port, "neutron_port_name", "stag-%s" % tenant.volt.s_tag)
                port.save()

            # tag the instance with the s-tag, so we can easily find the
            # instance later
            if tenant.volt and tenant.volt.s_tag:
                tags = Tag.objects.filter(name="s_tag", value=tenant.volt.s_tag)
                if not tags:
                    tag = Tag(service=tenant.owner, content_type=instance.self_content_type_id, object_id=instance.id, name="s_tag", value=str(tenant.volt.s_tag))
                    tag.save()

            # VTN-CORD needs a WAN address for the VM, so that the VM can
            # be configured.
            tags = Tag.objects.filter(content_type=instance.self_content_type_id, object_id=instance.id, name="vm_vrouter_tenant")
            if not tags:
                vrouter = self.allocate_public_service_instance(address_pool_name="addresses_vsg",
                                                                subscriber_service=tenant.owner)
                vrouter.set_attribute("tenant_for_instance_id", instance.id)
                vrouter.save()
                # TODO: potential partial failure
                tag = Tag(service=tenant.owner, content_type=instance.self_content_type_id, object_id=instance.id, name="vm_vrouter_tenant", value="%d" % vrouter.id)
                tag.save()

            instance.no_sync = False   # allow the synchronizer to run now
            super(VSGTenantPolicy, self).save_instance(instance)
        except:
            # need to clean up any failures here
            raise


