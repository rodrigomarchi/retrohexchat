import * as protocol from "../../../../js/lib/games/surround/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Light Trails", protocol, fixtures);
