extends RefCounted
class_name AnimationRigProfile

## Shared retarget contract for authored humanoid motion on Styloo's deform rig.
## Keep this sparse: helper, twist, face, and garment bones stay in the model,
## but are not required channels for a portable body-motion clip.

const PROFILE_ID := "ophelia_humanoid_v1"
const FORWARD_AXIS := "+Z"
const MODEL_SCALE := 0.8

const QUATERNIUS_TO_ELF := {
	"Hips": "DEF-spine",
	"Spine": "DEF-spine.001",
	"Chest": "DEF-spine.003",
	"UpperChest": "DEF-spine.004",
	"Neck": "DEF-spine.005",
	"Head": "DEF-spine.006",
	"LeftShoulder": "DEF-shoulder.L",
	"LeftUpperArm": "DEF-upper_arm.L",
	"LeftLowerArm": "DEF-forearm.L",
	"LeftHand": "DEF-hand.L",
	"RightShoulder": "DEF-shoulder.R",
	"RightUpperArm": "DEF-upper_arm.R",
	"RightLowerArm": "DEF-forearm.R",
	"RightHand": "DEF-hand.R",
	"LeftUpperLeg": "DEF-thigh.L",
	"LeftLowerLeg": "DEF-shin.L",
	"LeftFoot": "DEF-foot.L",
	"LeftToes": "DEF-toe.L",
	"RightUpperLeg": "DEF-thigh.R",
	"RightLowerLeg": "DEF-shin.R",
	"RightFoot": "DEF-foot.R",
	"RightToes": "DEF-toe.R",
}

const TARGET_BONES := [
	"DEF-spine", "DEF-spine.001", "DEF-spine.003", "DEF-spine.004", "DEF-spine.005", "DEF-spine.006",
	"DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L",
	"DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R",
	"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R",
]

const DIRECTION_CHILD := {
	"LeftShoulder": "LeftUpperArm", "LeftUpperArm": "LeftLowerArm", "LeftLowerArm": "LeftHand",
	"RightShoulder": "RightUpperArm", "RightUpperArm": "RightLowerArm", "RightLowerArm": "RightHand",
	"LeftUpperLeg": "LeftLowerLeg", "LeftLowerLeg": "LeftFoot", "LeftFoot": "LeftToes",
	"RightUpperLeg": "RightLowerLeg", "RightLowerLeg": "RightFoot", "RightFoot": "RightToes",
}
