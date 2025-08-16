import { createPoll } from "ags/time";

export const time = createPoll("", 1000, ["date", "+%a %d %H:%M"]);