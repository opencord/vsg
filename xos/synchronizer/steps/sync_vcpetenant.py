import hashlib
import os
import socket
import sys
import base64
import time
from urlparse import urlparse
from django.db.models import F, Q
from xos.config import Config
from synchronizers.base.syncstep import SyncStep
from synchronizers.base.ansible_helper import run_template_ssh
from synchronizers.base.SyncInstanceUsingAnsible import SyncInstanceUsingAnsible
from core.models import Service, Slice, Tag, ModelLink, CoarseTenant, Tenant, ServiceMonitoringAgentInfo
from services.vsg.models import VSGService, VSGTenant
from xos.logger import Logger, logging

# Deal with configurations where the hpc service is not onboarded
try:
    from services.hpc.models import HpcService, CDNPrefix
    hpc_service_onboarded=True
except:
    hpc_service_onboarded=False

# hpclibrary will be in steps/..
parentdir = os.path.join(os.path.dirname(__file__),"..")
sys.path.insert(0,parentdir)

logger = Logger(level=logging.INFO)

ENABLE_QUICK_UPDATE=False

class SyncVSGTenant(SyncInstanceUsingAnsible):
    provides=[VSGTenant]
    observes=VSGTenant
    requested_interval=0
    template_name = "sync_vcpetenant.yaml"
    watches = [ModelLink(CoarseTenant,via='coarsetenant'), ModelLink(ServiceMonitoringAgentInfo,via='monitoringagentinfo')]

    def __init__(self, *args, **kwargs):
        super(SyncVSGTenant, self).__init__(*args, **kwargs)

    def fetch_pending(self, deleted):
        if (not deleted):
            objs = VSGTenant.get_tenant_objects().filter(Q(enacted__lt=F('updated')) | Q(enacted=None),Q(lazy_blocked=False))
        else:
            objs = VSGTenant.get_deleted_tenant_objects()

        return objs

    def get_vcpe_service(self, o):
        if not o.provider_service:
            return None

        vcpes = VSGService.get_service_objects().filter(id=o.provider_service.id)
        if not vcpes:
            return None

        return vcpes[0]

    def get_extra_attributes(self, o):
        # This is a place to include extra attributes that aren't part of the
        # object itself. In the case of vCPE, we need to know:
        #   1) the addresses of dnsdemux, to setup dnsmasq in the vCPE
        #   2) CDN prefixes, so we know what URLs to send to dnsdemux
        #   4) vlan_ids, for setting up networking in the vCPE VM

        vcpe_service = self.get_vcpe_service(o)

        dnsdemux_ip = None
        cdn_prefixes = []

        cdn_config_fn = "/opt/xos/synchronizers/vsg/cdn_config"
        if os.path.exists(cdn_config_fn):
            # manual CDN configuration
            #   the first line is the address of dnsredir
            #   the remaining lines are domain names, one per line
            lines = file(cdn_config_fn).readlines()
            if len(lines)>=2:
                dnsdemux_ip = lines[0].strip()
                cdn_prefixes = [x.strip() for x in lines[1:] if x.strip()]
        elif hpc_service_onboarded:
            # automatic CDN configuiration
            #    it learns everything from CDN objects in XOS
            #    not tested on pod.
            if vcpe_service.backend_network_label:
                # Connect to dnsdemux using the network specified by
                #     vcpe_service.backend_network_label
                for service in HpcService.objects.all():
                    for slice in service.slices.all():
                        if "dnsdemux" in slice.name:
                            for instance in slice.instances.all():
                                for ns in instance.ports.all():
                                    if ns.ip and ns.network.labels and (vcpe_service.backend_network_label in ns.network.labels):
                                        dnsdemux_ip = ns.ip
                if not dnsdemux_ip:
                    logger.info("failed to find a dnsdemux on network %s" % vcpe_service.backend_network_label,extra=o.tologdict())
            else:
                # Connect to dnsdemux using the instance's public address
                for service in HpcService.objects.all():
                    for slice in service.slices.all():
                        if "dnsdemux" in slice.name:
                            for instance in slice.instances.all():
                                if dnsdemux_ip=="none":
                                    try:
                                        dnsdemux_ip = socket.gethostbyname(instance.node.name)
                                    except:
                                        pass
                if not dnsdemux_ip:
                    logger.info("failed to find a dnsdemux with a public address",extra=o.tologdict())

            for prefix in CDNPrefix.objects.all():
                cdn_prefixes.append(prefix.prefix)

        dnsdemux_ip = dnsdemux_ip or "none"

        s_tags = []
        c_tags = []
        if o.volt:
            s_tags.append(o.volt.s_tag)
            c_tags.append(o.volt.c_tag)

        try:
            full_setup = Config().observer_full_setup
        except:
            full_setup = True

        safe_macs=[]
        if vcpe_service.url_filter_kind == "safebrowsing":
            if o.volt and o.volt.subscriber:
                for user in o.volt.subscriber.devices:
                    level = user.get("level",None)
                    mac = user.get("mac",None)
                    if level in ["G", "PG"]:
                        if mac:
                            safe_macs.append(mac)


        docker_opts = []
        if vcpe_service.docker_insecure_registry:
            reg_name = vcpe_service.docker_image_name.split("/",1)[0]
            docker_opts.append("--insecure-registry " + reg_name)

        fields = {"s_tags": s_tags,
                "c_tags": c_tags,
                "docker_remote_image_name": vcpe_service.docker_image_name,
                "docker_local_image_name": vcpe_service.docker_image_name, # vcpe_service.docker_image_name.split("/",1)[1].split(":",1)[0],
                "docker_opts": " ".join(docker_opts),
                "dnsdemux_ip": dnsdemux_ip,
                "cdn_prefixes": cdn_prefixes,
                "full_setup": full_setup,
                "isolation": o.instance.isolation,
                "safe_browsing_macs": safe_macs,
                "container_name": "vcpe-%s-%s" % (s_tags[0], c_tags[0]),
                "dns_servers": [x.strip() for x in vcpe_service.dns_servers.split(",")],
                "url_filter_kind": vcpe_service.url_filter_kind }

        # add in the sync_attributes that come from the SubscriberRoot object

        if o.volt and o.volt.subscriber and hasattr(o.volt.subscriber, "sync_attributes"):
            for attribute_name in o.volt.subscriber.sync_attributes:
                fields[attribute_name] = getattr(o.volt.subscriber, attribute_name)

        return fields

    def sync_fields(self, o, fields):
        # the super causes the playbook to be run
        super(SyncVSGTenant, self).sync_fields(o, fields)

    def run_playbook(self, o, fields):
        ansible_hash = hashlib.md5(repr(sorted(fields.items()))).hexdigest()
        quick_update = (o.last_ansible_hash == ansible_hash)

        if ENABLE_QUICK_UPDATE and quick_update:
            logger.info("quick_update triggered; skipping ansible recipe",extra=o.tologdict())
        else:
            if o.instance.isolation in ["container", "container_vm"]:
                raise Exception("probably not implemented")
                super(SyncVSGTenant, self).run_playbook(o, fields, "sync_vcpetenant_new.yaml")
            else:
                super(SyncVSGTenant, self).run_playbook(o, fields, template_name="sync_vcpetenant_vtn.yaml")

        o.last_ansible_hash = ansible_hash

    def delete_record(self, m):
        pass

    def handle_service_monitoringagentinfo_watch_notification(self, monitoring_agent_info):
        if not monitoring_agent_info.service:
            logger.info("handle watch notifications for service monitoring agent info...ignoring because service attribute in monitoring agent info:%s is null" % (monitoring_agent_info))
            return

        if not monitoring_agent_info.target_uri:
            logger.info("handle watch notifications for service monitoring agent info...ignoring because target_uri attribute in monitoring agent info:%s is null" % (monitoring_agent_info))
            return

        objs = VSGTenant.get_tenant_objects().all()
        for obj in objs:
            if obj.provider_service.id != monitoring_agent_info.service.id:
                logger.info("handle watch notifications for service monitoring agent info...ignoring because service attribute in monitoring agent info:%s is not matching" % (monitoring_agent_info))
                return

            instance = self.get_instance(obj)
            if not instance:
               logger.warn("handle watch notifications for service monitoring agent info...: No valid instance found for object %s" % (str(obj)))
               return

            logger.info("handling watch notification for monitoring agent info:%s for VSGTenant object:%s" % (monitoring_agent_info, obj))

            #Run ansible playbook to update the routing table entries in the instance
            fields = self.get_ansible_fields(instance)
            fields["ansible_tag"] =  obj.__class__.__name__ + "_" + str(obj.id) + "_service_monitoring"
            
            #Parse the monitoring agent target_uri
            url = urlparse(monitoring_agent_info.target_uri)

            #Assuming target_uri is rabbitmq URI
            fields["rabbit_user"] = url.username
            fields["rabbit_password"] = url.password
            fields["rabbit_host"] = url.hostname

            template_name = "sync_monitoring_agent.yaml"
            super(SyncVSGTenant, self).run_playbook(obj, fields, template_name)
        pass
