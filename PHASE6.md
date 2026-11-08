# Pen Fight: The Aura Wars · Phase 6

## Aura and pen collection

Classic is unlocked by default. A completed eligible online best-of-three grants 20 Aura to each participant and 30 extra to the winner. Each player must have made an accepted physical flick, and both must still be in the server at the deciding round. Draws replay without a payout. Matches with a timed-out round, cancelled matches and disconnects before completion earn nothing. Rewards for the same opponent are limited to one per 180 seconds per profile. The profile shows counts of rewarded matches and wins. A completed rematch uses a fresh match ID and must meet the same eligibility and cooldown rules.

The five unlocks cost 100, 250, 500, 850 and 1,300 Aura. Unlocking and equipping are separate server-validated actions, available from the menu. The rupee labels describe the classroom style. The lobby waits for loadouts before starting its countdown. In online play each player uses their own saved pen. In Practice and Local Hotseat the initiating player's equipped pen goes to Blue and Red uses Classic. The Studio-only legacy Hotseat entry uses Classic on both sides.

## Handling

All variants reuse the existing welded pen model and identical Body and Ballpoint collision geometry. Tints, grip ring accents and barrel markings distinguish the pens while retaining team-color components. The server sets density and friction on both physical contact parts. Launch speed is calculated from the established charge curve and capped at the original 28 studs/s maximum. The spin multiplier scales the impulse's off-center lever arm. The fixed 240 Hz solver is retained.

| Level / Pen | Aura | Density | Friction | Launch scale | Spin scale | Trade-off |
|---|---:|---:|---:|---:|---:|---|
| 1 Classic | 0 | 1.40 | .100 | 1.00 | 1.00 | Baseline |
| 2 Gripper | 100 | 1.40 | .180 | 1.04 | .85 | Grip and launch force for short shots, with shorter travel |
| 3 Swift | 250 | 1.20 | .080 | 1.07 | 1.00 | Fast with less mass at contact |
| 4 Spinner | 500 | 1.40 | .105 | .92 | 1.28 | More off-center rotation, slower launch |
| 5 Heavyweight | 850 | 1.63 | .105 | .88 | .84 | More mass, slower launch and less rotation |
| 6 Precision | 1,300 | 1.40 | .075 | .94 | .60 | Lower spin and grip with a slower launch |

Server Play used production flicks on six cloned assemblies at .55 charge and .85 studs of offset. The figures below are from a single controlled measurement per pen.

| Pen | Assembly mass | Peak launch (studs/s) | Peak spin (rad/s) | Early travel (studs) |
|---|---:|---:|---:|---:|
| Classic | 3.534 | 11.06 | 1.96 | 1.34 |
| Gripper | 3.534 | 11.38 | 1.73 | 1.33 |
| Swift | 3.029 | 11.89 | 2.10 | 1.46 |
| Spinner | 3.534 | 10.14 | 2.31 | 1.35 |
| Heavyweight | 4.114 | 9.68 | 1.45 | 1.27 |
| Precision | 3.534 | 10.41 | 1.10 | 1.27 |

## Saving

`ProgressionService` stores schema version 1 in `PenFightProgress_v1`, keyed by player ID. Records hold the Aura balance, owned pen IDs, equipped ID, completed matches, wins, recent opponent receipts, last operation ID and a server session lease. All mutations use `UpdateAsync`. A lease expires after 120 seconds and is renewed every 40 seconds while the profile is idle. Writes are serialized per player, retry transient errors and use an operation ID to reconcile a retry after a lost response. Disconnect and shutdown wait for in-flight transactions and earned payouts before releasing the lease. Unverified writes fail closed, and unsupported records are preserved.

Studio sessions leave the real DataStore disabled and use Classic with purchases and rewards unavailable. The isolated test double exercises the same load, commit, award and release methods. The two online payouts are separate per-player transactions. During a storage outage one payout can fail after the other commits. An unverified write disables that profile for the session and a new session reloads the stored result. [Roblox DataStore retry and session guidance](https://create.roblox.com/docs/cloud-services/data-stores/best-practices)

## Test results

| Check | Status | Evidence |
|---|---|---|
| Fresh profile | PASS | Isolated store started with zero Aura and Classic equipped. |
| Award amounts and idempotency | PASS | Isolated store recorded 50 Aura for the winner and 20 for the other participant. A simulated lost write response and same-match replay did not add a second award. |
| Unlock debit, invalid and duplicate requests | PASS | Insufficient balance, unknown pen, unowned equip and duplicate unlock were rejected. Gripper deducted exactly 100 Aura. |
| Equip, reconnect and session conflicts | PASS | The test double retained ownership, equipped ID, balance and match statistics after closing and reopening a profile. A competing lease and unknown schema were blocked. |
| Live DataStore persistence and published rewards | NOT TESTED | No Studio API access or live data was used. No build was published. |
| Variant previews and physical differences | PASS | All six previews rendered. Live server fixtures measured six different finishes and the expected friction, mass, speed and spin trade-offs. Full competitive balance remains untested. |
| Native tip contact | PASS | All nine Classic fixtures and all nine mixed-variant fixtures passed with native tip contact. |
| Two-client match and progression dispatch | PASS | Both players landed two physical shots, both saw the same 2–0 result, and the completed match dispatched rewards once. With Studio persistence disabled, no balance was credited. |
| Draw replay | PASS | A controlled server draw left scores and reward dispatch unchanged and replayed the round. |
| Rematch and timeout eligibility | PASS | Two HUD votes started a fresh match ID and reset eligibility. Controlled deadline expirations produced a result without another reward dispatch. |
| Cancellation and disconnect | PASS | Leaving and controlled disconnect cleared the match slots and lobby reservation without awarding progression. |
| Equipped loadout in gameplay | PASS | A real client unlock and equip request used an isolated seeded record. Gripper spent 100 Aura and appeared as Blue in the next match with measured .18 collider friction and the expected barrel color. |
| Practice and Hotseat | PASS | Actual drag-and-release was accepted in both modes. Practice stayed on Blue and Hotseat handed control to Red. |
| Mobile collection layout | PASS | Portrait opened the collection and returned Home. Landscape opened the collection, advanced to Gripper and returned Home through the scrollable panel. |
| Full portrait collection interactions and physical-device usability | NOT TESTED | Portrait navigation smoke test only. Unlock and equip require an available store. |
| Sampled runtime errors and data integrity | PASS | The successful two-client run recorded no server or client runtime errors. Isolated-store checks retained records under retries, lease conflicts and invalid requests. Production backend integrity was not tested. |

Raw isolated-store, physics and simulator evidence is in `qa/Phase6-results.json`. The two-client results are in `qa/Phase6-multiplayer-results.json`. The first attempt timed out waiting for client 2. The second reached a physical match result, then the harness missed the first landscape Rematch tap. The final run passed all 14 checks after the test client compensated for the 47-pixel horizontal input offset of the 685 × 338 Studio simulator viewport. This adjustment was made to the test's Vote click only. The temporary harness was removed from the Studio place.

## Delivery

The local `Pen-Fight-Aura-Wars.Phase6.rbxl` export matches all 32 runtime Luau sources and retains fixed stepping. Binary SHA-256 is `72B9700942192945892BAE06AE0772BE37FD7E7BC87804F01A96E4889F331818`. The pre-Phase 6 backup and Phase 5B.1 export both hash to `F0D0DB5CD3ED95BB1AFA100ED102E52D7F4B6B2DC31F43B12FACE671683215A6`. The build remains local. All six rotating collection previews and the profile were captured from the running Studio client in `screenshots/Phase6/`.
