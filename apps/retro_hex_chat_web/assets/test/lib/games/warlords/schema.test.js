import * as protocol from "../../../../js/lib/games/warlords/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Hex Warlords", protocol, fixtures);
