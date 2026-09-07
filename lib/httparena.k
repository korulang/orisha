// HttpArena route bundle — NOT part of the public Orisha API.
//
// Discipline: orisha/httparena/DISCIPLINE.md — validate.sh + gcannon on Linux
// are ground truth; local wrk is smoke only.
//
// Koru nests `orisha/httparena:*` under the framework module when this companion
// pair lives beside `index.k`. The benchmark *entry* is `orisha/httparena/main.k`
// (genhttp-kestrel shape: import orisha, wire handler, serve).

import orisha

pub tor pipeline { req: *orisha:Request } -> orisha:Response
pub tor baseline { req: *orisha:Request } -> orisha:Response
pub tor json { req: *orisha:Request, count: string } -> orisha:Response
pub tor dispatch { req: *orisha:Request } -> orisha:Response
