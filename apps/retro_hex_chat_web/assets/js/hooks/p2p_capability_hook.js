import { detectCapabilities, requestPermission } from "../lib/p2p";

const P2PCapabilityHook = {
  mounted() {
    detectCapabilities().then((capabilities) => {
      this.pushEvent("p2p_capabilities", capabilities);
    });

    this.handleEvent("p2p_request_permission", ({ type }) => {
      requestPermission(type).then((result) => {
        this.pushEvent("permission_result", result);
      });
    });
  },
};

export default P2PCapabilityHook;
