import * as protocol from "../../../../js/lib/games/pong/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Pong", protocol, fixtures);
