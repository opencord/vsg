
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


import hashlib
import os
import socket
import sys
import base64
import time
from urlparse import urlparse
from synchronizers.new_base.SyncInstanceUsingAnsible import SyncInstanceUsingAnsible
from synchronizers.new_base.modelaccessor import *
from synchronizers.new_base.ansible_helper import run_template_ssh
from xos.logger import Logger, logging

# hpclibrary will be in steps/..
parentdir = os.path.join(os.path.dirname(__file__),"..")
sys.path.insert(0,parentdir)

logger = Logger(level=logging.INFO)

ENABLE_QUICK_UPDATE=False

class SyncVSGServiceInstance(SyncInstanceUsingAnsible):
    provides=[VSGServiceInstance]
    observes=VSGServiceInstance
    requested_interval=0
    template_name = "sync_vsgserviceinstance.yaml"
    watches = [ModelLink(ServiceDependency,via='servicedependency'), ModelLink(ServiceMonitoringAgentInfo,via='monitoringagentinfo')]

    def __init__(self, *args, **kwargs):
        super(SyncVSGServiceInstance, self).__init__(*args, **kwargs)

    def get_vsg_service(self, o):
        return o.owner.leaf_model

    def get_extra_attributes(self, o):
        # This is a place to include extra attributes that aren't part of the
        # object itself. In the case of vSG, we need to know:
        #   1) the addresses of dnsdemux, to setup dnsmasq in the vSG
        #   2) CDN prefixes, so we know what URLs to send to dnsdemux
        #   4) vlan_ids, for setting up networking in the vSG VM

        vsg_service = self.get_vsg_service(o)

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

        dnsdemux_ip = dnsdemux_ip or "none"

        s_tags = []
        c_tags = []
        if o.volt:
            s_tags.append(o.volt.s_tag)
            c_tags.append(o.volt.c_tag)

        full_setup = True

        safe_macs=[]
        if vsg_service.url_filter_kind == "safebrowsing":
            if o.volt and o.volt.subscriber:
                for user in o.volt.subscriber.devices and hasattr(o.volt.subscriber, "devices"):
                    level = user.get("level",None)
                    mac = user.get("mac",None)
                    if level in ["G", "PG"]:
                        if mac:
                            safe_macs.append(mac)

        docker_opts = []
        if vsg_service.docker_insecure_registry:
            reg_name = vsg_service.docker_image_name.split("/",1)[0]
            docker_opts.append("--insecure-registry " + reg_name)

        fields = {"s_tags": s_tags,
                "c_tags": c_tags,
                "docker_remote_image_name": vsg_service.docker_image_name,
                "docker_local_image_name": vsg_service.docker_image_name,
                "docker_opts": " ".join(docker_opts),
                "dnsdemux_ip": dnsdemux_ip,
                "cdn_prefixes": cdn_prefixes,
                "full_setup": full_setup,
                "isolation": o.instance.isolation,
                "safe_browsing_macs": safe_macs,
                "container_name": "vsg-%s-%s" % (s_tags[0], c_tags[0]),
                "dns_servers": [x.strip() for x in vsg_service.dns_servers.split(",")],
                "url_filter_kind": vsg_service.url_filter_kind }

        # Some subscriber models may not implement all fields that we look for, so specify some defaults.
        fields["firewall_rules"] = ""
        fields["firewall_enable"] = False
        fields["url_filter_enable"] = False
        fields["url_filter_level"] = "PG"
        fields["cdn_enable"] = False
        fields["uplink_speed"] = 1000000000
        fields["downlink_speed"] = 1000000000
        fields["enable_uverse"] = True
        fields["status"] = "enabled"

        # add in the sync_attributes that come from the subscriber object
        if o.volt and o.volt.subscriber and hasattr(o.volt.subscriber, "sync_attributes"):
            for attribute_name in o.volt.subscriber.sync_attributes:
                fields[attribute_name] = getattr(o.volt.subscriber, attribute_name)

        return fields

    def sync_fields(self, o, fields):
        # the super causes the playbook to be run
        super(SyncVSGServiceInstance, self).sync_fields(o, fields)

    def run_playbook(self, o, fields):
        ansible_hash = hashlib.md5(repr(sorted(fields.items()))).hexdigest()
        quick_update = (o.last_ansible_hash == ansible_hash)

        if ENABLE_QUICK_UPDATE and quick_update:
            logger.info("quick_update triggered; skipping ansible recipe",extra=o.tologdict())
        else:
            if o.instance.isolation in ["container", "container_vm"]:
                raise Exception("Not implemented")
            else:
                super(SyncVSGServiceInstance, self).run_playbook(o, fields)

        o.last_ansible_hash = ansible_hash

    def sync_record(self, o):
        if (not o.policed) or (o.policed<o.updated):
            self.defer_sync(o, "waiting on model policy")
        super(SyncVSGServiceInstance, self).sync_record(o)

    def delete_record(self, o):
        if (not o.policed) or (o.policed<o.updated):
            self.defer_sync(o, "waiting on model policy")
        # do not call super, as we don't want to re-run the playbook

    def handle_service_monitoringagentinfo_watch_notification(self, monitoring_agent_info):
        if not monitoring_agent_info.service:
            logger.info("handle watch notifications for service monitoring agent info...ignoring because service attribute in monitoring agent info:%s is null" % (monitoring_agent_info))
            return

        if not monitoring_agent_info.target_uri:
            logger.info("handle watch notifications for service monitoring agent info...ignoring because target_uri attribute in monitoring agent info:%s is null" % (monitoring_agent_info))
            return

        objs = VSGServiceInstance.objects.all()
        for obj in objs:
            if obj.owner.id != monitoring_agent_info.service.id:
                logger.info("handle watch notifications for service monitoring agent info...ignoring because service attribute in monitoring agent info:%s is not matching" % (monitoring_agent_info))
                return

            instance = self.get_instance(obj)
            if not instance:
               logger.warn("handle watch notifications for service monitoring agent info...: No valid instance found for object %s" % (str(obj)))
               return

            logger.info("handling watch notification for monitoring agent info:%s for VSGServiceInstance object:%s" % (monitoring_agent_info, obj))

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
            super(SyncVSGServiceInstance, self).run_playbook(obj, fields, template_name)

