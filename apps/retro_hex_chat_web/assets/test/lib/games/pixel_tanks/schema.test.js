import * as protocol from "../../../../js/lib/games/pixel_tanks/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Pixel Tanks", protocol, fixtures);
