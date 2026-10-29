import * as protocol from "../../../../js/lib/games/star_duel/protocol.js";
import { describeWireSchema } from "../../../support/games/wire_schema.js";
import fixtures from "./fixtures/wire.json";

describeWireSchema("Star Duel", protocol, fixtures);
