extends RefCounted
## Random display names; different users may receive the same name.

const ADJECTIVES: Array[String] = [
	"Brave", "Calm", "Clever", "Happy", "Friendly", "Gentle",
	"Kind", "Lucky", "Quick", "Quiet", "Bright", "Bold",
	"Cool", "Curious", "Eager", "Fancy", "Funny", "Jolly",
	"Lively", "Merry", "Nice", "Proud", "Silly", "Sleepy",
	"Smart", "Sunny", "Swift", "Warm", "Wild", "Wise",
]

const NOUNS: Array[String] = [
	"Moose", "Bear", "Fox", "Wolf", "Owl", "Otter",
	"Rabbit", "Deer", "Duck", "Goose", "Hawk", "Eagle",
	"Robin", "Sparrow", "Panda", "Tiger", "Lion", "Zebra",
	"Horse", "Mouse", "Beaver", "Badger", "Squirrel", "Turtle",
	"Frog", "Seal", "Whale", "Dolphin", "Penguin", "Falcon",
]

static func generate() -> String:
	return ADJECTIVES[randi_range(0, ADJECTIVES.size() - 1)] + NOUNS[randi_range(0, NOUNS.size() - 1)]
