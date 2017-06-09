import unittest
from mock import patch
import mock

import os, sys
sys.path.append("../../..")
sys.path.append("../../new_base/model_policies")
config = basic_conf = os.path.abspath(os.path.dirname(os.path.realpath(__file__)) + "/test_config.yaml")
from xosconfig import Config
Config.init(config, 'synchronizer-config-schema.yaml')

import synchronizers.new_base.modelaccessor

from model_policy_vsgtenant import VSGTenantPolicy

class MockVSGTenant:
    provider_service = None
    deleted = False
    instance = None
    volt = None

class TestModelPolicyVsgTenant(unittest.TestCase):
    def setUp(self):
        self.policy = VSGTenantPolicy()
        self.tenant = MockVSGTenant()
        
    def test_manage_container_no_volt(self):
        with self.assertRaises(Exception) as e:
            self.policy.manage_container(self.tenant)
        self.assertEqual(e.exception.message, "This VSG container has no volt")

if __name__ == '__main__':
    unittest.main()

