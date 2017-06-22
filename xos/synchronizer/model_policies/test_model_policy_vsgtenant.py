import unittest
from mock import patch
import mock
import pdb

import os, sys
sys.path.append("../../..")
sys.path.append("../../new_base/model_policies")
config = basic_conf = os.path.abspath(os.path.dirname(os.path.realpath(__file__)) + "/test_config.yaml")
from xosconfig import Config
Config.init(config, 'synchronizer-config-schema.yaml')

import synchronizers.new_base.modelaccessor

import synchronizers.new_base.model_policies.model_policy_tenantwithcontainer
import model_policy_vsgtenant
from model_policy_vsgtenant import VSGTenantPolicy
from synchronizers.new_base.model_policies.model_policy_tenantwithcontainer import LeastLoadedNodeScheduler

MockObjectStores = {}

class MockObjectList:
    item_list = None

    def __init__(self, initial=None):
        self.id_counter = 0
        if initial:
            self.item_list=initial
        elif self.item_list is None:
            self.item_list=[]

    def get_items(self):
        return self.item_list

    def count(self):
        return len(self.get_items())

    def first(self):
        return self.get_items()[0]

    def all(self):
        return self.get_items()

    def filter(self, **kwargs):
        items = self.get_items()
        for (k,v) in kwargs.items():
            items = [x for x in items if getattr(x,k) == v]
        return items

    def get(self, **kwargs):
        objs = self.filter(**kwargs)
        if not objs:
            raise Exception("No objects matching %s" % str(kwargs))
        return objs[0]

class MockObjectStore(MockObjectList):
    def save(self, o):
        if (not hasattr(o,"id")) or (not o.id):
            for item in self.get_items():
                if item.id >= self.id_counter:
                    self.id_counter = item.id + 1

            o.id = self.id_counter
            self.id_counter = self.id_counter + 1

        for item in self.get_items():
            if item.id == o.id:
                item = o
                break
        else:
            self.get_items().append(o)

class MockObject(object):
    objects = None
    id = None
    def __init__(self, **kwargs):
        for (k,v) in kwargs.items():
            setattr(self,k,v)
    @property
    def self_content_type_id(self):
        return self.__class__.__name__
    def save(self):
        if self.objects:
            self.objects.save(self)
    def delete(self):
        pass

def get_MockObjectStore(x):
    return globals()["Mock%sObjects" % x]()

class MockFlavorObjects(MockObjectStore): pass
class MockFlavor(MockObject):
    objects = get_MockObjectStore("Flavor")
    name = None

class MockInstanceObjects(MockObjectStore): pass
class MockInstance(MockObject):
    objects = get_MockObjectStore("Instance")
    name = None

class MockDeploymentObjects(MockObjectStore): pass
class MockDeployment(MockObject):
    objects = get_MockObjectStore("Deployment")
    name = None

class MockUserObjects(MockObjectStore): pass
class MockUser(MockObject):
    objects = get_MockObjectStore("User")
    email = None

class MockSliceObjects(MockObjectStore): pass
class MockSlice(MockObject):
    objects = get_MockObjectStore("Slice")
    name = None
    default_node = None
    networks = None

class MockNodeObjects(MockObjectStore): pass
class MockNode(MockObject):
    objects = get_MockObjectStore("Node")
    hostname = None
    site_deployment = None

class MockImageObjects(MockObjectStore): pass
class MockImage(MockObject):
    objects = get_MockObjectStore("Image")
    name = None

class MockTagObjects(MockObjectStore): pass
class MockTag(MockObject):
    objects = get_MockObjectStore("Tag")
    name = None
    value = None

class MockNetworkTemplateObjects(MockObjectStore): pass
class MockNetworkTemplate(MockObject):
    objects = get_MockObjectStore("NetworkTemplate")
    name = None
    visibility = None

class MockNetworkParameterTypeObjects(MockObjectStore): pass
class MockNetworkParameterType(MockObject):
    objects = get_MockObjectStore("NetworkParameterType")
    name = None

class MockNetworkParameterObjects(MockObjectStore): pass
class MockNetworkParameter(MockObject):
    objects = get_MockObjectStore("NetworkParameter")
    value = None
    parameter_id = None

class MockNetworkObjects(MockObjectStore): pass
class MockNetwork(MockObject):
    objects = get_MockObjectStore("Network")
    name = None
    template = None

class MockPortObjects(MockObjectStore): pass
class MockPort(MockObject):
    objects = get_MockObjectStore("Port")
    name = None
    def set_parameter(self, name, value):
        pass

class MockVRouterTenantObjects(MockObjectStore): pass
class MockVRouterTenant(MockObject):
    objects = get_MockObjectStore("VRouterTenant")
    public_ip = None
    public_mac = None
    address_pool_id = None
    def set_attribute(self, name, value):
        pass

class MockVoltTenantObjects(MockObjectStore): pass
class MockVoltTenant(MockObject):
    objects = get_MockObjectStore("VoltTenant")
    c_tag = None
    s_tag = None

class MockVSGServiceObjects(MockObjectStore): pass
class MockVSGService(MockObject):
    objects = get_MockObjectStore("VSGService")
    name = None
    node_label = None
    slices = None
    def __init__(self, **kwargs):
        super(MockVSGService, self).__init__(**kwargs)

class MockVSGTenantObjects(MockObjectStore): pass
class MockVSGTenant(MockObject):
    objects = get_MockObjectStore("VSGTenant")
    provider_service = None
    deleted = False
    instance = None
    creator = None
    volt = None
    service_specific_attribute = {}

    def get_image(self):
        return None

class TestModelPolicyVsgTenant(unittest.TestCase):
    def setUp(self):
        self.policy = VSGTenantPolicy()
        self.tenant = MockVSGTenant()
        self.user = MockUser(email="testadmin@test.org")
        self.tenant = MockVSGTenant(creator=self.user)
        self.flavor = MockFlavor(name="m1.small")
        self.npt_ctag = MockNetworkParameterType(name="c_tag", id=1)
        self.npt_stag = MockNetworkParameterType(name="s_tag", id=2)
        self.npt_neutron_port_name = MockNetworkParameterType(name="neutron_port_name", id=3)
        synchronizers.new_base.model_policies.model_policy_tenantwithcontainer.Instance = MockInstance
        synchronizers.new_base.model_policies.model_policy_tenantwithcontainer.Flavor = MockFlavor
        synchronizers.new_base.model_policies.model_policy_tenantwithcontainer.Tag = MockTag
        synchronizers.new_base.model_policies.model_policy_tenantwithcontainer.Node = MockNode
        model_policy_vsgtenant.Instance = MockInstance
        model_policy_vsgtenant.Flavor = MockFlavor
        model_policy_vsgtenant.Tag = MockTag
        model_policy_vsgtenant.VSGService = MockVSGService
        model_policy_vsgtenant.Node = MockNode
        model_policy_vsgtenant.Port = MockPort
        model_policy_vsgtenant.NetworkParameterType = MockNetworkParameterType
        model_policy_vsgtenant.NetworkParameter = MockNetworkParameter
        
    def test_manage_container_no_volt(self):
        with self.assertRaises(Exception) as e:
            self.policy.manage_container(self.tenant)
        self.assertEqual(e.exception.message, "This VSG container has no volt")

    @patch.object(MockNetworkParameterTypeObjects, "get_items")
    @patch.object(MockNodeObjects, "get_items")
    @patch.object(MockFlavorObjects, "get_items")
    @patch.object(MockVSGServiceObjects, "get_items")
    @patch.object(MockVSGTenant, "volt")
    @patch.object(MockVSGTenant, "save")
    @patch.object(VSGTenantPolicy, "get_image")
    @patch.object(VSGTenantPolicy, "allocate_public_service_instance")
    @patch.object(LeastLoadedNodeScheduler, "pick")
    @patch.object(MockNode, "site_deployment")
    @patch.object(MockInstance, "save")
    @patch.object(MockInstance, "delete")
    @patch.object(MockSlice, "networks")
    @patch.object(MockPort, "set_parameter")
    def test_manage_container(self, port_set_parameter, slice_networks, instance_delete, instance_save, site_deployment,
                              pick, get_psi, get_image, tenant_save, volt,
                              vsgservice_objects, flavor_objects, node_objects, npt_objects):
        # setup mocks
        node = MockNode(hostname="my.node.com")
        slice = MockSlice(name="mysite_test1", default_flavor=self.flavor, default_isolation="vm")
        priv_template = MockNetworkTemplate(name="access_network", visibility="private")
        priv_network = MockNetwork(name="mysite_test1_private", template=priv_template)
        image = MockImage(name="trusty-server-multi-nic")
        deployment = MockDeployment(name="testdeployment")
        vrtenant = MockVRouterTenant(public_ip="1.2.3.4", public_mac="01:02:03:04:05:06")
        vsgservice=MockVSGService(name="myvsgservice", id=1, slices=MockObjectList(initial=[slice]))
        vsgservice_objects.return_value = [vsgservice]
        self.tenant.provider_service = vsgservice
        volt.s_tag=222
        volt.c_tag=111
        get_image.return_value = image
        get_psi.return_value = vrtenant
        pick.return_value = (node, None)
        site_deployment.deployment = deployment
        flavor_objects.return_value=[self.flavor]
        node_objects.return_value=[node]
        npt_objects.return_value=[self.npt_stag, self.npt_ctag, self.npt_neutron_port_name]
        slice_networks.all.return_value = [priv_network]
        # done setup mocks

        # call manage_container
        self.policy.manage_container(self.tenant)

        # make sure Instance was created
        self.assertNotEqual(self.tenant.instance, None)
        self.assertEqual(self.tenant.instance.creator.email, "testadmin@test.org")
        self.assertEqual(self.tenant.instance.image.name, "trusty-server-multi-nic")
        self.assertEqual(self.tenant.instance.flavor.name, "m1.small")
        self.assertEqual(self.tenant.instance.isolation, "vm")
        self.assertEqual(self.tenant.instance.node.hostname, "my.node.com")
        self.assertEqual(self.tenant.instance.slice.name, "mysite_test1")
        self.assertEqual(self.tenant.instance.parent, None)
        instance_save.assert_called()
        instance_delete.assert_not_called()
        tenant_save.assert_called()

        # check the access port
        port = Port.objects.first()
        port.set_parameter.assert_called_with(port, "c_tag", 111)
        port.set_parameter.assert_called_with(port, "s_tag", 222)
        port.set_parameter.assert_called_with(port, "neutron_port_name", "stag-222")


lan_network = self.get_lan_network(tenant, instance)
port = self.find_or_make_port(instance, lan_network)
self.port_set_parameter(port, "c_tag", tenant.volt.c_tag)
self.port_set_parameter(port, "s_tag", tenant.volt.s_tag)
self.port_set_parameter(port, "neutron_port_name", "stag-%s" % tenant.volt.s_tag)
port.save()

if __name__ == '__main__':
    unittest.main()

