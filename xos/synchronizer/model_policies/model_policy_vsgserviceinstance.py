
# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


from synchronizers.new_base.modelaccessor import VSGServiceInstance, AddressManagerServiceInstance, VSGService, Tag, Flavor, Instance, Port, NetworkParameterType, NetworkParameter, ServiceInstance, model_accessor
from synchronizers.new_base.model_policies.model_policy_tenantwithcontainer import TenantWithContainerPolicy, LeastLoadedNodeScheduler
from synchronizers.new_base.exceptions import *
from xosapi.orm import ORMGenericObjectNotFoundException

class VSGServiceInstancePolicy(TenantWithContainerPolicy):
    model_name = "VSGServiceInstance"

    def handle_create(self, service_instance):
        return self.handle_update(service_instance)

    def handle_update(self, service_instance):
        if (service_instance.link_deleted_count>0) and (not service_instance.provided_links.exists()):
            # if the last provided_link has just gone away, then self-destruct
            self.logger.info("The last provided link has been deleted -- self-destructing.")
            # TODO: We shouldn't have to call handle_delete ourselves. The model policy framework should handle this
            #       for us, but it isn't. I think that's happening is that serviceinstance.delete() isn't setting a new
            #       updated timestamp, since there's no way to pass `always_update_timestamp`, and therefore the
            #       policy framework doesn't know that the object has changed and needs new policies. For now, the
            #       workaround is to just call handle_delete ourselves.
            self.handle_delete(service_instance)
            # Note that if we deleted the Instance in handle_delete, then django may have cascade-deleted the service
            # instance by now. Thus we have to guard our delete, to check that the service instance still exists.
            if VSGServiceInstance.objects.filter(id=service_instance.id).exists():
                service_instance.delete()
            else:
                self.logger.info("Tenant %s is already deleted" % service_instance)
            return

        self.manage_container(service_instance)
        self.manage_address_service_instance(service_instance)
        self.cleanup_orphans(service_instance)

    def handle_delete(self, service_instance):
        if service_instance.instance and (not service_instance.instance.deleted):
            all_service_instances_this_instance = VSGServiceInstance.objects.filter(instance_id=service_instance.instance.id)
            other_service_instances_this_instance = [x for x in all_service_instances_this_instance if x.id != service_instance.id]
            if (not other_service_instances_this_instance):
                self.logger.info("VSG Instance %s is now unused -- deleting" % service_instance.instance)
                self.delete_instance(service_instance, service_instance.instance)
            else:
                self.logger.info("VSG Instance %s has %d other service instances attached" % (service_instance.instance, len(other_service_instances_this_instance)))

    def manage_address_service_instance(self, service_instance):
        if service_instance.deleted:
            return

        if service_instance.address_service_instance is None:
            address_service_instance = self.allocate_public_service_instance(address_pool_name="addresses_vsg", subscriber_tenant=service_instance)
            address_service_instance.save()

    def cleanup_orphans(self, service_instance):
        # ensure vSG only has one AddressManagerServiceInstance
        cur_asi = service_instance.address_service_instance
        for link in service_instance.subscribed_links.all():
            # TODO: hardcoded dependency
            # cast from ServiceInstance to AddressManagerServiceInstance
            asis = AddressManagerServiceInstance.objects.filter(id = link.provider_service_instance.id)
            for asi in asis:
                if (not cur_asi) or (asi.id != cur_asi.id):
                    asi.delete()

    def get_vsg_service(self, service_instance):
        return VSGService.objects.get(id=service_instance.owner.id)

    def find_instance_for_s_tag(self, s_tag):
        tags = Tag.objects.filter(name="s_tag", value=s_tag)
        for tag in tags:
            try:
                return tag.content_object
            except ORMGenericObjectNotFoundException:
                self.logger.warning("Dangling Instance reference for s-tag %s. Deleting Tag object." % s_tag)
                tag.delete()

        return None

    def find_or_make_instance_for_s_tag(self, service_instance):
        instance = self.find_instance_for_s_tag(service_instance.volt.s_tag)
        if instance:
            if instance.no_sync:
                # if no_sync is still set, then perhaps we failed while saving it and need to retry.
                self.save_instance(service_instance, instance)
            return instance

        desired_image = self.get_image(service_instance)

        flavors = Flavor.objects.filter(name="m1.small")
        if not flavors:
            raise SynchronizerConfigurationError("No m1.small flavor")

        slice = service_instance.owner.slices.first()

        (node, parent) = LeastLoadedNodeScheduler(slice, label=self.get_vsg_service(service_instance).node_label).pick()

        assert (slice is not None)
        assert (node is not None)
        assert (desired_image is not None)
        assert (node.site_deployment.deployment is not None)
        assert (desired_image is not None)

        assert(service_instance.volt)
        assert(service_instance.volt.subscriber)
        assert(service_instance.volt.subscriber.creator)

        instance = Instance(slice=slice,
                            node=node,
                            image=desired_image,
                            creator=service_instance.volt.subscriber.creator,
                            deployment=node.site_deployment.deployment,
                            flavor=flavors[0],
                            isolation=slice.default_isolation,
                            parent=parent)

        self.save_instance(service_instance, instance)

        return instance

    def manage_container(self, service_instance):
        if service_instance.deleted:
            return

        if not service_instance.volt:
            raise SynchronizerConfigurationError("This VSG container has no volt")

        if service_instance.instance:
            # We're good.
            return

        instance = self.find_or_make_instance_for_s_tag(service_instance)
        service_instance.instance = instance
        # TODO: possible for partial failure here?
        service_instance.save()

    def find_or_make_port(self, instance, network, **kwargs):
        port = Port.objects.filter(instance_id=instance.id, network_id=network.id)
        if port:
            port = port[0]
        else:
            port = Port(instance=instance, network=network, **kwargs)
            port.save()
        return port

    def get_lan_network(self, service_instance, instance):
        slice = service_instance.owner.slices.all()[0]
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

    def delete_instance(self, service_instance, instance):
        # delete the `s_tag` tags
        tags = Tag.objects.filter(service_id=service_instance.owner.id, content_type=instance.self_content_type_id,
                                  object_id=instance.id, name="s_tag")
        for tag in tags:
            tag.delete()

        tags = Tag.objects.filter(content_type=instance.self_content_type_id, object_id=instance.id,
                                  name="vm_vrouter_tenant")
        for tag in tags:
            address_manager_instances = list(ServiceInstance.objects.filter(id=tag.value))
            tag.delete()

            # TODO: Potential partial failure

            for address_manager_instance in address_manager_instances:
                self.logger.info("Deleting address_manager_instance %s" % address_manager_instance)
                address_manager_instance.delete()

        instance.delete()

    def save_instance(self, service_instance, instance):
        instance.volumes = "/etc/dnsmasq.d,/etc/ufw"
        instance.no_sync = True   # prevent instance from being synced until we're done with it
        super(VSGServiceInstancePolicy, self).save_instance(instance)
        try:
            if instance.isolation in ["container", "container_vm"]:
                raise Exception("Not supported")

            if instance.isolation in ["vm"]:
                lan_network = self.get_lan_network(service_instance, instance)
                port = self.find_or_make_port(instance, lan_network)
                self.port_set_parameter(port, "c_tag", service_instance.volt.c_tag)
                self.port_set_parameter(port, "s_tag", service_instance.volt.s_tag)
                self.port_set_parameter(port, "neutron_port_name", "stag-%s" % service_instance.volt.s_tag)
                port.save()

            # tag the instance with the s-tag, so we can easily find the
            # instance later
            if service_instance.volt and service_instance.volt.s_tag:
                tags = Tag.objects.filter(name="s_tag", value=service_instance.volt.s_tag)
                if not tags:
                    tag = Tag(service=service_instance.owner, content_type=instance.self_content_type_id, object_id=instance.id, name="s_tag", value=str(service_instance.volt.s_tag))
                    tag.save()

            # VTN-CORD needs a WAN address for the VM, so that the VM can
            # be configured.
            tags = Tag.objects.filter(content_type=instance.self_content_type_id, object_id=instance.id, name="vm_vrouter_tenant")
            if not tags:
                address_service_instance = self.allocate_public_service_instance(address_pool_name="addresses_vsg",
                                                                                 subscriber_service=service_instance.owner)
                address_service_instance.set_attribute("tenant_for_instance_id", instance.id)
                address_service_instance.save()
                # TODO: potential partial failure
                tag = Tag(service=service_instance.owner, content_type=instance.self_content_type_id, object_id=instance.id, name="vm_vrouter_tenant", value="%d" % address_service_instance.id)
                tag.save()

            instance.no_sync = False   # allow the synchronizer to run now
            super(VSGServiceInstancePolicy, self).save_instance(instance)
        except:
            # need to clean up any failures here
            raise


