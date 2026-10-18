# HUE MASSACRE — Story Bible

> **One line: the last colours in the world are locked in four halls. A knight
> with no colour comes to take them, hall by hall, and the ones who guard them
> will not let go.**
>
> This file is the single source of truth for every story string in the game
> (verses, herald lines, barks, screens). If a string in code disagrees with this
> file, one of them is a bug. Mechanics that the story is built on are marked
> **[rule]** — those are in `scripts/color_theory.gd` and must not be diluted.

---

## 1. The world in five sentences

Long ago the **Wheel** turned, and every colour in the world came off it.

Then someone broke it. The colours ran out into the four quarters of the world,
and every knight who ever swore an oath **wore their colour as armour** — the
oath is the hue, the hue is the oath.

The world has been getting greyer ever since, because colour **spends**. A hall
that uses its colour fades; a knight who dies spills the last of theirs.

Four **halls** still hold colour, each guarding a **quarter of the Wheel** — the
only four colours left. The halls live off them.

Nobody has a colour to spare. Everybody is between colours and pretending.

## 2. The colour rules (story version of the mechanics)

| In the world | In the game |
|---|---|
| A hue is an oath; it is worn as armour and it is **hard to break** — only its opposite breaks it | **[rule]** complement → shatter (×2.5, stagger) |
| Wearing a hue that is already yours means nothing — your steel just drinks it | **[rule]** same hue → absorbed (×0.2) |
| Two colours that meet run together into a third | **[rule]** paint blends on the floor; red + blue = violet |
| Your colour can be **stolen off your blade**: kill a knight and their hue stays on your steel | **[rule]** absorbing a kill takes the dead hue |
| Standing in your own spilled colour, you are the wall — nobody sees you | **[rule]** paint veil (now only a *first-strike* tool; see 6) |
| Two knights of opposite hues cancel each other out completely | **[rule]** complements cancel — kills inside the window double the score |

**The theft is the story.** Everything the player does to get stronger is the
same act: take someone's colour. The game never stops saying it.

## 3. The Unsworn

A knight with no house and no hue. Their colour was spent — that is all the game
ever says, and it is enough. What that means:

- No oath, so no armour: every sworn knight can wound them, and their steel
  holds any hue it takes, but never keeps one.
- No name. In this world you are **named after the colour you wear**, so a
  colourless knight is nobody — the crowd literally cannot chant for them.
- They want a name more than they want a colour, and those turn out to be the
  same want.

**They never speak. Not once, until the end.** Their only line is their name,
and the ending is the only place they have one to give (see 9).

## 4. The Champion, and the turn

The champion of the Wheel wears **every** colour and belongs to none. He is what
the game's ending is made of:

> **He was the last Unsworn.**

He walked into the four halls the same way — took the quarters, took the
colours, took a name off the crowd. And the office is the trap: to hold all
colours is to own none of them, so the Champion is exactly what the Unsworn
started as, made enormous. He does not stop the player. He *invites* them.

- His summons are not soldiers: they are **Aspirants** — the next lot of nobodies
  the halls sent to try.
- His lines in the fight are not boasts, they are a sales pitch:
  *"Take it. Take all of it."*, *"I was you. You will be me."*
- When he falls, he does not die. He **kneels** (the existing line is right), and
  offers the office — and the crowd names the Unsworn either way. That is the
  ending: the wheel gets a new wearer, and the wheel always needs one.

## 5. The four halls and their wardens

Each hall is one arena (the layouts already exist). Each has a **warden** (a boss
with its own abilities) guarding a **quarter of the Wheel** (the reward).

### Hall I — THE OPEN SAND — *the quarter is red*
- **Warden:** THE SUN'S WARDEN. Heavy, unhurried, absolutely certain.
  *The Warrior, at warden scale.*
- **Abilities:** shield stance (facing the player, guards everything — must be
  broken with a complement or by getting around it), ground slam with a ring
  shockwave, bull charge.
- **Teaches:** the shatter. *His oath is thick; only its opposite cuts it.*
- **Quarter:** EMBER. Rewards the **HEAVY STRIKE**.

### Hall II — THE BANNERED HALL — *the quarter is violet*
- **Warden:** THE TWIN WARDENS — two, one red and one blue, and they fight as one.
  *Two knights; the hall's twin lanes are theirs.*
- **Ability (the fight's point):** when one twin dies, the survivor **takes up
  their paint** and rises changed — red + blue becomes **violet**, stronger, with
  both movesets. The lesson (blending) is performed by the enemy, not explained.
- **Teaches:** mixing. *Where their paint meets, a third colour is born.*
- **Quarter:** VIOLET. Rewards the **BOW** — their reach, taken.

### Hall III — THE DEEP RING — *the quarter is green*
- **Warden:** THE THORN WARDEN. A monk of the ring, patient as a root.
  *The Monk, staff and all.*
- **Abilities:** a hue **ward** around herself (immune to everything except the
  ward's complement — find the opposite hue or do nothing), heals herself and
  her sworn, grows thorns out of the floor, summons.
- **Teaches:** complementary contrast as a *condition* — the first time the player
  must hunt for the opposite hue under pressure.
- **Quarter:** THORN. Rewards the **WARD** (a heal/absorptive bubble — the art
  taken off the enemy).

### Hall IV — THE WHEEL — *the quarter is gold*
- **Warden:** THE CHAMPION OF THE WHEEL. Lancer. Rotation, charge, Aspirants.
- **Adds:** the quarter storm — the wheel's spokes sweep the floor while his hue
  turns, so the only safe ground moves. Everything the other three halls taught,
  at once, faster.
- **The turn:** he kneels. The office has a new wearer.

## 6. The sworn (why the enemies never stop)

The wardens' soldiers are **the sworn**: pawns, knights, harriers, archers,
monks, lancers. They guard the last colour in the world, and every one of them
knows exactly what happens if it leaves — the hall goes grey, then the people in
it. So:

- They are not evil and they are not stupid. They are **right**, and they know
  the Unsworn is stealing.
- **Once they see you, they never stop.** The oath is total — no searching, no
  giving up, no walking home. The vision cones are gone with the stealth.
- Their barks are the story's small print — short, and aimed at the player:
  *"Not this one. Not the last one."* · *"It's all we have left!"* ·
  *"He told you it was yours?"* · *"You'll be him one day."*
- One **first strike** exists and no more: standing in paint of your own hue
  keeps a sworn knight from noticing you *before* the fight starts. After that,
  camouflage is over — you have to face them.
- A knight that spots you **shouts** (the alarm), and the oath carries: nearby
  sworn hear it. The shout replaces the cone.

## 7. The arc, beat by beat

| Where | What the player reads |
|---|---|
| **Opening screen** (new) | The herald's proclamation: the Wheel broken, the four quarters, the price of a colour, "you have none" — plus the rules, as live hue swatches. Then: *space to enter the melee*. |
| **Hall verse** | One stanza of the same hymn, one per hall, naming the quarter kept there. |
| **Hall banner** | The warden is announced by name and title. |
| **In the fight** | Sworn barks (motive), the crowd's attention (the score), the herald's waves. |
| **Warden down** | The quarter is taken: a shard beat, the new ability shown by its name. |
| **Hall clear** | One line: what the hall looks like now that its colour is going. (The sand does not care; the people do.) |
| **The Wheel** | The Champion's invitation, the turn, the kneel. |
| **Win page** | The crowd names them. The Unsworn's one line. |
| **Death** | *"the melee goes on without you"* — a knight with no name was never here. |

## 8. Voice & typography (how it is written)

- **The herald** speaks in banners (existing system): announcements, waves,
  phase changes, quarters taken. Upper case, no adjectives, present tense.
- **The verses** are a hymn in four stanzas — the halls' own words, which is why
  they are the only place the story is allowed to be beautiful.
- **The sworn** speak in barks: six words or fewer, second person, to you.
- **The crowd** is never a character, only a judgement: the score, the
  multiplier, and finally the naming.
- No cutscenes, no dialogue trees, no lore dumps. If a line cannot be delivered
  by a system that already exists, it does not go in.

## 9. The ending, and the name

The naming was always in the game (`WIN_TITLE`, `hud.show_banner("THE UNSWORN IS
NAMED")`). The story gives it a mechanism:

- The crowd names you from the colour you are **wearing** when the Champion
  kneels: *the name is the hue you took last*. So the name is different every
  run, and the player's own play style chooses it (`ColorTheory.color_name`).
- Rank S → **NAMED**. The rank *is* the ending.
- The Unsworn's single line, spoken once in the whole game: their name. Draft:

  > **"The one I kept."**

  (Alternative, if we want it simpler: just the name itself, e.g. *"Crimson."*)

## 10. Deliberately simple

The one-minute explanation, for anyone who asks what the game is:

> "Four halls hold the last colour in the world. You have none. Take theirs."

Everything else — the oath, the theft, the office — is there for whoever plays
all four halls.
