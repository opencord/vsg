
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


import unittest
from mock import patch
import mock

import os, sys
sys.path.append("../../..")
config = os.path.abspath(os.path.dirname(os.path.realpath(__file__)) + "/test_config.yaml")
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
    owner = None
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
        self.tenant = MockVSGTenant(creator=self.user, id=1)
        self.flavor = MockFlavor(name="m1.small")
        self.npt_ctag = MockNetworkParameterType(name="c_tag", id=1)
        self.npt_stag = MockNetworkParameterType(name="s_tag", id=2)
        self.npt_neutron_port_name = MockNetworkParameterType(name="neutron_port_name", id=3)
        self.node = MockNode(hostname="my.node.com")
        self.slice = MockSlice(name="mysite_test1", default_flavor=self.flavor, default_isolation="vm")
        self.priv_template = MockNetworkTemplate(name="access_network", visibility="private")
        self.priv_network = MockNetwork(name="mysite_test1_private", template=self.priv_template)
        self.image = MockImage(name="trusty-server-multi-nic")
        self.deployment = MockDeployment(name="testdeployment")
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

    @patch.object(VSGTenantPolicy, "manage_container")
    @patch.object(VSGTenantPolicy, "manage_vrouter")
    @patch.object(VSGTenantPolicy, "cleanup_orphans")
    def test_handle_create(self, cleanup_orphans, manage_vrouter, manage_container):
        self.policy.handle_create(self.tenant)
        manage_container.assert_called_with(self.tenant)
        manage_vrouter.assert_called_with(self.tenant)
        cleanup_orphans.assert_called_with(self.tenant)

    @patch.object(VSGTenantPolicy, "manage_container")
    @patch.object(VSGTenantPolicy, "manage_vrouter")
    @patch.object(VSGTenantPolicy, "cleanup_orphans")
    def test_handle_update(self, cleanup_orphans, manage_vrouter, manage_container):
        self.policy.handle_create(self.tenant)
        manage_container.assert_called_with(self.tenant)
        manage_vrouter.assert_called_with(self.tenant)
        cleanup_orphans.assert_called_with(self.tenant)

    @patch.object(MockVRouterTenant, "delete")
    def test_handle_delete_vrouter_exist(self, vroutertenant_delete):
        vrtenant = MockVRouterTenant()
        self.tenant.vrouter = vrtenant
        self.policy.handle_delete(self.tenant)
        vroutertenant_delete.assert_called()

    @patch.object(MockVRouterTenant, "delete")
    def test_handle_delete_vrouter_noexist(self, vroutertenant_delete):
        self.tenant.vrouter = None
        self.policy.handle_delete(self.tenant)
        vroutertenant_delete.assert_not_called()

    @patch.object(MockVRouterTenantObjects, "get_items")
    @patch.object(MockVRouterTenant, "delete")
    def test_cleanup_orphans(self, vroutertenant_delete, vroutertenant_objects):
        vrtenant = MockVRouterTenant(id=1)
        self.tenant.vrouter = vrtenant
        some_other_vrtenant = MockVRouterTenant(id=2, subscriber_tenant_id = self.tenant.id)
        vroutertenant_objects.get_items = [some_other_vrtenant]
        self.policy.handle_delete(self.tenant)
        vroutertenant_delete.assert_called()

    @patch.object(MockTag, "objects")
    def test_find_instance_for_s_tag_noexist(self, tag_objects):
        tag_objects.filter.return_value = []
        instance = self.policy.find_instance_for_s_tag(3)
        self.assertEqual(instance, None)

    @patch.object(MockTag, "objects")
    def test_find_instance_for_s_tag(self, tag_objects):
        tagged_instance = MockInstance()
        tag = MockTag(content_object = tagged_instance)
        tag_objects.filter.return_value = [tag]
        instance = self.policy.find_instance_for_s_tag(3)
        self.assertEqual(instance, tagged_instance)

    def test_manage_container_no_volt(self):
        with self.assertRaises(Exception) as e:
            self.policy.manage_container(self.tenant)
        self.assertEqual(e.exception.message, "This VSG container has no volt")

    @patch.object(VSGTenantPolicy, "find_or_make_instance_for_s_tag")
    @patch.object(MockVSGTenant, "save")
    @patch.object(MockVSGTenant, "volt")
    def test_manage_container_noinstance(self, volt, tenant_save, find_or_make_instance_for_s_tag):
        instance = MockInstance()
        volt.s_tag=222
        volt.c_tag=111
        find_or_make_instance_for_s_tag.return_value = instance
        self.policy.manage_container(self.tenant)
        self.assertEqual(self.tenant.instance, instance)
        tenant_save.assert_called()

    @patch.object(VSGTenantPolicy, "find_or_make_instance_for_s_tag")
    @patch.object(MockVSGTenant, "save")
    @patch.object(MockVSGTenant, "volt")
    def test_manage_container_hasinstance(self, volt, tenant_save, find_or_make_instance_for_s_tag):
        instance = MockInstance()
        volt.s_tag=222
        volt.c_tag=111
        self.tenant.instance = instance
        self.policy.manage_container(self.tenant)
        find_or_make_instance_for_s_tag.assert_not_called()
        self.assertEqual(self.tenant.instance, instance)
        tenant_save.assert_not_called()

    @patch.object(VSGTenantPolicy, "find_or_make_instance_for_s_tag")
    @patch.object(MockVSGTenant, "save")
    @patch.object(MockVSGTenant, "volt")
    def test_manage_container_deleted(self, volt, tenant_save, find_or_make_instance_for_s_tag):
        self.tenant.deleted = True
        self.policy.manage_container(self.tenant)
        find_or_make_instance_for_s_tag.assert_not_called()
        tenant_save.assert_not_called()

    @patch.object(MockPort, "save")
    @patch.object(MockPort, "objects")
    def test_find_or_make_port_noexist(self, port_objects, port_save):
        instance = MockInstance(id=123)
        network = MockInstance(id=456)
        port_objects.filter.return_value = []
        port=self.policy.find_or_make_port(instance, network)
        self.assertNotEqual(port, None)
        port_save.assert_called()

    @patch.object(MockPort, "save")
    @patch.object(MockPort, "objects")
    def test_find_or_make_port_exists(self, port_objects, port_save):
        someport = MockPort()
        def mock_port_filter(network_id, instance_id):
            if (network_id==456) and (instance_id==123):
                return [someport]
            return None
        instance = MockInstance(id=123)
        network = MockInstance(id=456)
        port_objects.filter.side_effect = mock_port_filter
        port=self.policy.find_or_make_port(instance, network)
        self.assertEqual(port, someport)
        port_save.assert_not_called()

    @patch.object(MockVSGServiceObjects, "get_items")
    def test_get_lan_network_noexist(self, vsgservice_objects):
        vsgservice=MockVSGService(name="myvsgservice", id=1, slices=MockObjectList(initial=[self.slice]))
        vsgservice_objects.return_value = [vsgservice]
        self.tenant.owner = vsgservice
        self.slice.networks = MockObjectList()
        with self.assertRaises(Exception) as e:
            self.policy.get_lan_network(self.tenant, None)
        self.assertEqual(e.exception.message, "No lan_network")

    @patch.object(MockVSGServiceObjects, "get_items")
    def test_get_lan_network(self, vsgservice_objects):
        vsgservice=MockVSGService(name="myvsgservice", id=1, slices=MockObjectList(initial=[self.slice]))
        vsgservice_objects.return_value = [vsgservice]
        self.tenant.owner = vsgservice
        self.slice.networks = MockObjectList([self.priv_network])
        lan_network = self.policy.get_lan_network(self.tenant, None)
        self.assertEqual(lan_network, self.priv_network)

    @patch.object(MockVSGServiceObjects, "get_items")
    def test_get_lan_network_toomany(self, vsgservice_objects):
        some_other_network = MockNetwork(name="mysite_test1_private", template=self.priv_template)
        vsgservice=MockVSGService(name="myvsgservice", id=1, slices=MockObjectList(initial=[self.slice]))
        vsgservice_objects.return_value = [vsgservice]
        self.tenant.owner = vsgservice
        self.slice.networks = MockObjectList([self.priv_network, some_other_network])
        with self.assertRaises(Exception) as e:
            lan_network = self.policy.get_lan_network(self.tenant, None)
        self.assertEqual(e.exception.message, "The vSG slice should only have one non-management private network")

    @patch.object(MockNetworkParameterTypeObjects, "get_items")
    def test_port_set_parameter_noparamexist(self, npt_objects):
        npt_objects.return_value = [self.npt_stag]
        port = MockPort()
        self.policy.port_set_parameter(port, "s_tag", "123")
        self.assertNotEqual(MockNetworkParameter.objects.all(), [])
        param = MockNetworkParameter.objects.first()
        self.assertEqual(param.value, "123")
        self.assertEqual(param.parameter, self.npt_stag)

    @patch.object(MockNetworkParameterTypeObjects, "get_items")
    @patch.object(MockNetworkParameterObjects, "get_items")
    def test_port_set_parameter_paramexist(self, np_objects, npt_objects):
        port = MockPort(id=1)
        np_orig = MockNetworkParameter(parameter_id=self.npt_stag.id, value="456", object_id=port.id, content_type=port.self_content_type_id)
        np_objects.return_value = [np_orig]
        npt_objects.return_value = [self.npt_stag]
        self.policy.port_set_parameter(port, "s_tag", "123")
        self.assertEqual(MockNetworkParameter.objects.count(), 1)
        param = MockNetworkParameter.objects.first()
        self.assertEqual(param.value, "123")

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
    @patch.object(VSGTenantPolicy, "port_set_parameter")
    def test_find_or_make_instance_for_s_tag(self, port_set_parameter, instance_delete, instance_save, site_deployment,
                              pick, get_psi, get_image, tenant_save, volt,
                              vsgservice_objects, flavor_objects, node_objects, npt_objects):
        # setup mocks
        vrtenant = MockVRouterTenant(public_ip="1.2.3.4", public_mac="01:02:03:04:05:06")
        vsgservice=MockVSGService(name="myvsgservice", id=1, slices=MockObjectList(initial=[self.slice]))
        vsgservice_objects.return_value = [vsgservice]
        self.tenant.owner = vsgservice
        volt.s_tag=222
        volt.c_tag=111
        get_image.return_value = self.image
        get_psi.return_value = vrtenant
        pick.return_value = (self.node, None)
        site_deployment.deployment = self.deployment
        flavor_objects.return_value=[self.flavor]
        node_objects.return_value=[self.node]
        npt_objects.return_value=[self.npt_stag, self.npt_ctag, self.npt_neutron_port_name]
        self.slice.networks = MockObjectList([self.priv_network])
        # done setup mocks

        # call the function under test
        instance = self.policy.find_or_make_instance_for_s_tag(self.tenant, self.tenant.volt.s_tag)

        # make sure Instance was created
        self.assertNotEqual(instance, None)
        self.assertEqual(instance.creator.email, "testadmin@test.org")
        self.assertEqual(instance.image.name, "trusty-server-multi-nic")
        self.assertEqual(instance.flavor.name, "m1.small")
        self.assertEqual(instance.isolation, "vm")
        self.assertEqual(instance.node.hostname, "my.node.com")
        self.assertEqual(instance.slice.name, "mysite_test1")
        self.assertEqual(instance.parent, None)
        instance_save.assert_called()
        instance_delete.assert_not_called()

        # Access Network Port should have tags to c-tag and s-tag
        port = MockPort.objects.first()
        self.assertEqual(port.instance, instance)
        self.assertEqual(port.network, self.priv_network)
        port_set_parameter.assert_has_calls([mock.call(port, "c_tag", 111),
                                             mock.call(port, "s_tag", 222),
                                             mock.call(port, "neutron_port_name", "stag-222")])

        # The instance should be tagged with the s-tag
        tag = MockTag.objects.get(name="s_tag")
        self.assertEqual(tag.value, "222")
        self.assertEqual(tag.object_id, instance.id)

        # The instance should have a tag pointing to its vrouter
        tag = MockTag.objects.get(name="vm_vrouter_tenant")
        self.assertNotEqual(tag.value, vrtenant.id)
        self.assertEqual(tag.object_id, instance.id)

        # Allocate_public_service_instance should have been called
        get_psi.assert_called()

    @patch.object(VSGTenantPolicy, "allocate_public_service_instance")
    def test_manage_vrouter(self, get_psi):
        vrtenant = MockVRouterTenant(public_ip="1.2.3.4", public_mac="01:02:03:04:05:06")
        get_psi.return_value = vrtenant

        self.tenant.vrouter = None

        self.policy.manage_vrouter(self.tenant)

        get_psi.assert_called_with(address_pool_name="addresses_vsg", subscriber_tenant=self.tenant)

if __name__ == '__main__':
    unittest.main()

