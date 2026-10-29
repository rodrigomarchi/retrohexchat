import * as protocol from "../../../../js/lib/games/hex_frost/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Hex Frost", protocol, fixtures);
