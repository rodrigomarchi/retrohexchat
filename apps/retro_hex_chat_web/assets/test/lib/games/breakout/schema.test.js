import * as protocol from "../../../../js/lib/games/breakout/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Block Breakers", protocol, fixtures);
