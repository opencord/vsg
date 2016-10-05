from services.vsg.models import VSGService
from service import XOSService

class XOSVsgService(XOSService):
    provides = "tosca.nodes.VSGService"
    xos_model = VSGService
    copyin_props = ["view_url", "icon_url", "enabled", "published", "public_key",
                    "private_key_fn", "versionNumber", "backend_network_label",
                    "dns_servers", "node_label"]

