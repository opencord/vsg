
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


sync_attributes = ("wan_container_ip", "wan_container_mac", "wan_container_netbits",
                   "wan_container_gateway_ip", "wan_container_gateway_mac",
                   "wan_vm_ip", "wan_vm_mac")

def __init__(self, *args, **kwargs):
    super(VSGTenant, self).__init__(*args, **kwargs)
    self.cached_address_service_instance=None

@property
def address_service_instance(self):
    address_service_instance = self.get_newest_subscribed_tenant(AddressManagerServiceInstance)
    if not address_service_instance:
        return None

    # always return the same object when possible
    if (self.cached_address_service_instance) and (self.cached_address_service_instance.id == address_service_instance.id):
        return self.cached_address_service_instance

    address_service_instance.caller = self.creator
    self.cached_address_service_instance = address_service_instance
    return address_service_instance

@address_service_instance.setter
def address_service_instance(self, value):
    raise XOSConfigurationError("VSGTenant.address_service_instance setter is not implemented")

@property
def volt(self):
    from services.volt.models import VOLTTenant
    if not self.subscriber_tenant:
        return None
    volts = VOLTTenant.objects.filter(id=self.subscriber_tenant.id)
    if not volts:
        return None
    return volts[0]

@volt.setter
def volt(self, value):
    raise XOSConfigurationError("VSGTenant.volt setter is not implemented")

@property
def ssh_command(self):
    if self.instance:
        return self.instance.get_ssh_command()
    else:
        return "no-instance"

def get_address_service_instance_field(self, name, default=None):
    if self.address_service_instance:
        return getattr(self.address_service_instance, name, default)
    else:
        return default

@property
def wan_container_ip(self):
    return self.get_address_service_instance_field("public_ip", None)

@property
def wan_container_mac(self):
    return self.get_address_service_instance_field("public_mac", None)

@property
def wan_container_netbits(self):
    return self.get_address_service_instance_field("netbits", None)

@property
def wan_container_gateway_ip(self):
    return self.get_address_service_instance_field("gateway_ip", None)

@property
def wan_container_gateway_mac(self):
    return self.get_address_service_instance_field("gateway_mac", None)

@property
def wan_vm_ip(self):
    tags = Tag.objects.filter(content_type=self.instance.get_content_type_key(), object_id=self.instance.id, name="vm_vrouter_tenant")
    if tags:
        tenant = AddressManagerServiceInstance.objects.get(id=tags[0].value)
        return tenant.public_ip
    else:
        raise Exception("no vm_vrouter_tenant tag for instance %s" % o.instance)

@property
def wan_vm_mac(self):
    tags = Tag.objects.filter(content_type=self.instance.get_content_type_key(), object_id=self.instance.id, name="vm_vrouter_tenant")
    if tags:
        tenant = AddressManagerServiceInstance.objects.get(id=tags[0].value)
        return tenant.public_mac
    else:
        raise Exception("no vm_vrouter_tenant tag for instance %s" % o.instance)

@property
def is_synced(self):
    return (self.enacted is not None) and (self.enacted >= self.updated)

@is_synced.setter
def is_synced(self, value):
    pass

def __xos_save_base(self, *args, **kwargs):
    if not self.creator:
        if not getattr(self, "caller", None):
            # caller must be set when creating a vCPE since it creates a slice
            raise XOSProgrammingError("VSGTenant's self.caller was not set")
        self.creator = self.caller
        if not self.creator:
            raise XOSProgrammingError("VSGTenant's self.creator was not set")

    return False

def delete(self, *args, **kwargs):
    super(VSGTenant, self).delete(*args, **kwargs)

