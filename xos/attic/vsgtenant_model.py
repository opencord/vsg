sync_attributes = ("wan_container_ip", "wan_container_mac", "wan_container_netbits",
                   "wan_container_gateway_ip", "wan_container_gateway_mac",
                   "wan_vm_ip", "wan_vm_mac")

def __init__(self, *args, **kwargs):
    super(VSGTenant, self).__init__(*args, **kwargs)
    self.cached_vrouter=None

@property
def vrouter(self):
    vrouter = self.get_newest_subscribed_tenant(VRouterTenant)
    if not vrouter:
        return None

    # always return the same object when possible
    if (self.cached_vrouter) and (self.cached_vrouter.id == vrouter.id):
        return self.cached_vrouter

    vrouter.caller = self.creator
    self.cached_vrouter = vrouter
    return vrouter

@vrouter.setter
def vrouter(self, value):
    raise XOSConfigurationError("VSGTenant.vrouter setter is not implemented")

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

def get_vrouter_field(self, name, default=None):
    if self.vrouter:
        return getattr(self.vrouter, name, default)
    else:
        return default

@property
def wan_container_ip(self):
    return self.get_vrouter_field("public_ip", None)

@property
def wan_container_mac(self):
    return self.get_vrouter_field("public_mac", None)

@property
def wan_container_netbits(self):
    return self.get_vrouter_field("netbits", None)

@property
def wan_container_gateway_ip(self):
    return self.get_vrouter_field("gateway_ip", None)

@property
def wan_container_gateway_mac(self):
    return self.get_vrouter_field("gateway_mac", None)

@property
def wan_vm_ip(self):
    tags = Tag.objects.filter(content_type=self.instance.get_content_type_key(), object_id=self.instance.id, name="vm_vrouter_tenant")
    if tags:
        tenant = VRouterTenant.objects.get(id=tags[0].value)
        return tenant.public_ip
    else:
        raise Exception("no vm_vrouter_tenant tag for instance %s" % o.instance)

@property
def wan_vm_mac(self):
    tags = Tag.objects.filter(content_type=self.instance.get_content_type_key(), object_id=self.instance.id, name="vm_vrouter_tenant")
    if tags:
        tenant = VRouterTenant.objects.get(id=tags[0].value)
        return tenant.public_mac
    else:
        raise Exception("no vm_vrouter_tenant tag for instance %s" % o.instance)

@property
def is_synced(self):
    return (self.enacted is not None) and (self.enacted >= self.updated)

@is_synced.setter
def is_synced(self, value):
    pass

def save(self, *args, **kwargs):
    if not self.creator:
        if not getattr(self, "caller", None):
            # caller must be set when creating a vCPE since it creates a slice
            raise XOSProgrammingError("VSGTenant's self.caller was not set")
        self.creator = self.caller
        if not self.creator:
            raise XOSProgrammingError("VSGTenant's self.creator was not set")

    super(VSGTenant, self).save(*args, **kwargs)

def delete(self, *args, **kwargs):
    super(VSGTenant, self).delete(*args, **kwargs)

