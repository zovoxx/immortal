class_name MessageFragments
extends RefCounted
## The eight fragments of the sealed Message. One breaks free every 25 zones ("Seal Breaks").

const TITLES: Array[String] = [
	"The First Seal", "The Second Seal", "The Third Seal", "The Fourth Seal",
	"The Fifth Seal", "The Sixth Seal", "The Seventh Seal", "The Last Seal",
]

const TEXT: Array[String] = [
	"To whoever stands at the End of the Road —\nIf this letter reaches you, the road has not swallowed every one of us. Do not open the gate until you have read all of it. Do not let it read you first.",
	"I cannot sign my name. Names are the first thing the road eats. Know only that I set out before the first relay fire was lit, and that I was not the first to carry this letter, nor will you be the last to have it handed to you.",
	"Every courier who falls makes the road a little shorter for the next. Their bodies are milestones. Their packs are pantries. This is not cruelty. This is how the road was built — one of us at a time.",
	"By now you have noticed the faces. The same jaw, the same eyes, a different name each time the fire wakes you. Do not be afraid of it. The relay fires do not make strangers. They only make more of us.",
	"We are one blood carried in many bodies. When one falls, the next wakes by the fire with this letter already in hand. I have done it more times than there are stars over the Salt. So have you. You simply don't remember yet.",
	"The hounds do not hunt us for meat. They follow our scent because they remember it. They were couriers once — the ones who reached the End, sat down, and listened to what was waiting there.",
	"What lives at the End of the Road speaks in the voice you most want to hear. It will tell you the journey is over. It will thank you. It will offer you rest. Rest is how it eats.",
	"So here is the warning, the whole of it: do not stop. Hand this letter to the thing at the End, and when it reads its own name written here — in your hand, in all our hands — it will remember it was once one of us. And then, at last, the road will let us all go home.",
]


static func zone_for(index: int) -> int:
	return (index + 1) * Game.config.fragment_every_zones
