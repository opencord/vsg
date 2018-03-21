
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
from mock import patch, call, Mock, MagicMock, PropertyMock
import mock

import os, sys

test_path=os.path.abspath(os.path.dirname(os.path.realpath(__file__)))
service_dir=os.path.join(test_path, "../../../..")
xos_dir=os.path.join(test_path, "../../..")
if not os.path.exists(os.path.join(test_path, "new_base")):
    xos_dir=os.path.join(test_path, "../../../../../../orchestration/xos/xos")
    services_dir=os.path.join(xos_dir, "../../xos_services")

# While transitioning from static to dynamic load, the path to find neighboring xproto files has changed. So check
# both possible locations...
def get_models_fn(service_name, xproto_name):
    name = os.path.join(service_name, "xos", xproto_name)
    if os.path.exists(os.path.join(services_dir, name)):
        return name
    else:
        name = os.path.join(service_name, "xos", "synchronizer", "models", xproto_name)
        if os.path.exists(os.path.join(services_dir, name)):
            return name
    raise Exception("Unable to find service=%s xproto=%s" % (service_name, xproto_name))

class TestSyncVSGServiceInstance(unittest.TestCase):
    def setUp(self):
        global SyncVSGServiceInstance, LeastLoadedNodeScheduler, MockObjectList

        self.sys_path_save = sys.path
        sys.path.append(xos_dir)
        sys.path.append(os.path.join(xos_dir, 'synchronizers', 'new_base'))

        config = os.path.join(test_path, "test_config.yaml")
        from xosconfig import Config
        Config.clear()
        Config.init(config, 'synchronizer-config-schema.yaml')

        from synchronizers.new_base.mock_modelaccessor_build import build_mock_modelaccessor
        build_mock_modelaccessor(xos_dir, services_dir, [get_models_fn("vsg", "vsg.xproto"),
                                                         get_models_fn("addressmanager", "addressmanager.xproto")])

        import synchronizers.new_base.modelaccessor
        import synchronizers.new_base.model_policies.model_policy_tenantwithcontainer
        import sync_vsgserviceinstance
        from sync_vsgserviceinstance import SyncVSGServiceInstance, model_accessor

        from mock_modelaccessor import MockObjectList

        # import all class names to globals
        for (k, v) in model_accessor.all_model_classes.items():
            globals()[k] = v

        # Some of the functions we call have side-effects. For example, creating a VSGServiceInstance may lead to creation of
        # tags. Ideally, this wouldn't happen, but it does. So make sure we reset the world.
        model_accessor.reset_all_object_stores()

        # attic functions that are not present in the mock model accessor
        AddressManagerServiceInstance.set_attribute = Mock()

        self.syncstep = SyncVSGServiceInstance()

        # set up an object hierarchy that represents a Service and ServiceInstance

        self.user = User(email="testadmin@test.org")
        self.service = VSGService(name="the_vsg_service",
                                  id=1,
                                  docker_image_name="reg/vsg_docker",
                                  docker_insecure_registry=True,
                                  dns_servers="dnsone,dnstwo",
                                  url_filter_kind=None,
                                  private_key_fn=os.path.join(test_path, "test_private_key"))
        self.subscriber = MagicMock(firewall_rules = "rule1",
                                    firewall_enable = True,
                                    url_filter_enable = True,
                                    url_filter_level="R",
                                    cdn_enable=True,
                                    uplink_speed=1234,
                                    downlink_speed=5678,
                                    enable_uverse=False,
                                    status="suspended",
                                    sync_attributes=["firewall_rules", "firewall_enable", "url_filter_enable",
                                                     "url_filter_level", "cdn_enable", "uplink_speed",
                                                     "downlink_speed", "enable_uverse", "status"])
        self.volt = MagicMock(s_tag=111, c_tag=222, subscriber=self.subscriber)
        self.tenant = VSGServiceInstance(id=401,
                                         volt=self.volt,
                                         owner=self.service,
                                         wan_container_ip="10.7.1.3",
                                         wan_container_netbits="24",
                                         wan_container_mac="02:42:0a:07:01:03",
                                         wan_container_gateway_ip="10.7.1.1",
                                         wan_vm_ip="10.7.1.2",
                                         wan_vm_mac="02:42:0a:07:01:02",
                                         sync_attributes = ["wan_container_ip", "wan_container_netbits", "wan_container_mac",
                                                        "wan_container_gateway_ip", "wan_vm_ip", "wan_vm_mac"])
        self.flavor = Flavor(name="m1.small")
        self.npt_ctag = NetworkParameterType(name="c_tag", id=1)
        self.npt_stag = NetworkParameterType(name="s_tag", id=2)
        self.npt_neutron_port_name = NetworkParameterType(name="neutron_port_name", id=501)
        self.priv_template = NetworkTemplate(name="access_network", visibility="private")
        self.priv_network = Network(name="mysite_test1_private", template=self.priv_template)
        self.image = Image(name="trusty-server-multi-nic")
        self.deployment = Deployment(name="testdeployment")
        self.user = User(email="smbaker", id=701)
        self.controller = Controller(id=101)
        self.node = Node(name="testnode")
        self.slice = Slice(name="mysite_test1", default_flavor=self.flavor, default_isolation="vm", service=self.service, id=301)
        self.instance = Instance(slice=self.slice,
                            instance_name="testinstance1_instance_name",
                            instance_id="testinstance1_instance_id",
                            name="testinstance1_name",
                            node=self.node,
                            creator=self.user,
                            controller=self.controller)
        self.tenant.instance = self.instance
        self.instance.get_ssh_ip = Mock(return_value="1.2.3.4")
        self.controllerslice = ControllerSlice(slice_id=self.slice.id, controller_id=self.controller.id, id=201)
        self.controlleruser = ControllerUser(user_id=self.user.id, controller_id=self.controller.id, id=601)

    def tearDown(self):
        sys.path = self.sys_path_save

    def test_get_vsg_service(self):
        with patch.object(VSGService.objects, "get_items") as vsgservice_objects:
            vsgservice_objects.return_value = [self.service]

            self.tenant.owner = self.service

            self.assertEqual(self.syncstep.get_vsg_service(self.tenant), self.service)

    def test_get_extra_attributes(self):
        with patch.object(VSGService.objects, "get_items") as vsgservice_objects:
            vsgservice_objects.return_value = [self.service]

            attrs = self.syncstep.get_extra_attributes(self.tenant)

            desired_attrs = {"s_tags": [111],
                             "c_tags": [222],
                             "docker_remote_image_name": "reg/vsg_docker",
                             "docker_local_image_name": "reg/vsg_docker",
                             "docker_opts": "--insecure-registry reg",
                             "dnsdemux_ip": "none",
                             "cdn_prefixes": [],
                             "full_setup": True,
                             "isolation": "vm",
                             "safe_browsing_macs": [],
                             "container_name": "vsg-111-222",
                             "dns_servers": ["dnsone", "dnstwo"],
                             "url_filter_kind": None,

                             "firewall_rules": "rule1",
                             "firewall_enable": True,
                             "url_filter_enable": True,
                             "url_filter_level": "R",
                             "cdn_enable": True,
                             "uplink_speed": 1234,
                             "downlink_speed": 5678,
                             "enable_uverse": False,
                             "status": "suspended"}

            self.assertDictContainsSubset(desired_attrs, attrs)


    def test_sync_record(self):
        with patch.object(VSGService.objects, "get_items") as vsgservice_objects, \
                patch.object(Slice.objects, "get_items") as slice_objects, \
                patch.object(User.objects, "get_items") as user_objects, \
                patch.object(ControllerSlice.objects, "get_items") as controllerslice_objects, \
                patch.object(ControllerUser.objects, "get_items") as controlleruser_objects, \
                patch.object(SyncVSGServiceInstance, "run_playbook") as run_playbook:
            slice_objects.return_value = [self.slice]
            vsgservice_objects.return_value = [self.service]
            controllerslice_objects.return_value = [self.controllerslice]
            controlleruser_objects.return_value = [self.controlleruser]
            user_objects.return_value = [self.user]

            self.tenant.updated = 10
            self.tenant.policed = 20
            self.tenant.enacted = None

            run_playbook.return_value = True

            self.syncstep.sync_record(self.tenant)

            run_playbook.assert_called()

            attrs = run_playbook.call_args[0][1]

            desired_attrs = {"username": "ubuntu",
                             "ansible_tag": "VSGServiceInstance_401",
                             "instance_name": "testinstance1_name",
                             "hostname": "testnode",
                             "private_key": "some_key\n",
                             "ssh_ip": "1.2.3.4",
                             "instance_id": "testinstance1_instance_id",

                             "wan_container_ip": "10.7.1.3",
                             "wan_container_netbits": "24",
                             "wan_container_mac": "02:42:0a:07:01:03",
                             "wan_container_gateway_ip": "10.7.1.1",
                             "wan_vm_ip": "10.7.1.2",
                             "wan_vm_mac": "02:42:0a:07:01:02",

                             "s_tags": [111],
                             "c_tags": [222],
                             "docker_remote_image_name": "reg/vsg_docker",
                             "docker_local_image_name": "reg/vsg_docker",
                             "docker_opts": "--insecure-registry reg",
                             "dnsdemux_ip": "none",
                             "cdn_prefixes": [],
                             "full_setup": True,
                             "isolation": "vm",
                             "safe_browsing_macs": [],
                             "container_name": "vsg-111-222",
                             "dns_servers": ["dnsone", "dnstwo"],
                             "url_filter_kind": None,

                             "firewall_rules": "rule1",
                             "firewall_enable": True,
                             "url_filter_enable": True,
                             "url_filter_level": "R",
                             "cdn_enable": True,
                             "uplink_speed": 1234,
                             "downlink_speed": 5678,
                             "enable_uverse": False,
                             "status": "suspended"}

            self.assertDictContainsSubset(desired_attrs, attrs)

    def test_sync_record_emptysubscriber(self):
        with patch.object(VSGService.objects, "get_items") as vsgservice_objects, \
                patch.object(Slice.objects, "get_items") as slice_objects, \
                patch.object(User.objects, "get_items") as user_objects, \
                patch.object(ControllerSlice.objects, "get_items") as controllerslice_objects, \
                patch.object(ControllerUser.objects, "get_items") as controlleruser_objects, \
                patch.object(SyncVSGServiceInstance, "run_playbook") as run_playbook:
            slice_objects.return_value = [self.slice]
            vsgservice_objects.return_value = [self.service]
            controllerslice_objects.return_value = [self.controllerslice]
            controlleruser_objects.return_value = [self.controlleruser]
            user_objects.return_value = [self.user]

            self.tenant.updated = 10
            self.tenant.policed = 20
            self.tenant.enacted = None

            self.volt.subscriber = MagicMock()

            run_playbook.return_value = True

            self.syncstep.sync_record(self.tenant)

            run_playbook.assert_called()

            attrs = run_playbook.call_args[0][1]

            desired_attrs = {"firewall_rules": "",
                             "firewall_enable": False,
                             "url_filter_enable": False,
                             "url_filter_level": "PG",
                             "cdn_enable": False,
                             "uplink_speed": 1000000000,
                             "downlink_speed": 1000000000,
                             "enable_uverse": True,
                             "status": "enabled"}

            self.assertDictContainsSubset(desired_attrs, attrs)

    def test_sync_record_no_policy(self):
        with patch.object(SyncVSGServiceInstance, "run_playbook") as run_playbook:

            self.tenant.updated = 10
            self.tenant.policed = 5   # policies need to be run
            self.tenant.enacted = None

            with self.assertRaises(Exception) as e:
                self.syncstep.sync_record(self.tenant)
            self.assertIn("due to waiting on model policy", e.exception.message)

            run_playbook.assert_not_called()

    def test_sync_record_instance_not_ready(self):
        with patch.object(SyncVSGServiceInstance, "run_playbook") as run_playbook:

            self.tenant.updated = 10
            self.tenant.policed = 20
            self.tenant.enacted = None

            self.instance.instance_name = None # no instance_name means instance is not ready

            with self.assertRaises(Exception) as e:
                self.syncstep.sync_record(self.tenant)
            self.assertIn("due to waiting on instance.instance_name", e.exception.message)

            run_playbook.assert_not_called()

    def test_delete_record_no_policy(self):
        self.tenant.updated = 10
        self.tenant.policed = 20
        self.tenant.enacted = None

        self.syncstep.delete_record(self.tenant)

        # delete doesn't actually do anything, so nothing to further test.

    def test_delete_record_no_policy(self):
        self.tenant.updated = 10
        self.tenant.policed = 5   # policies need to be run
        self.tenant.enacted = None

        with self.assertRaises(Exception) as e:
            self.syncstep.delete_record(self.tenant)
        self.assertIn("due to waiting on model policy", e.exception.message)

if __name__ == '__main__':
    unittest.main()


