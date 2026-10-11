using Godot;

/// <summary>Cached procedural carriage pass over the authored gait.</summary>
[GlobalClass]
public partial class GraceMotion : SkeletonModifier3D
{
	private enum Bone
	{
		Hips, Chest, UpperChest, Head,
		UpperArmL, ForearmL, UpperArmR, ForearmR,
		ThighL, ThighR, FootL, ToeL, FootR, ToeR, Count
	}

	private static readonly string[] BoneNames =
	{
		"DEF-spine", "DEF-spine.003", "DEF-spine.004", "DEF-spine.006",
		"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
		"DEF-thigh.L", "DEF-thigh.R", "DEF-foot.L", "DEF-toe.L", "DEF-foot.R", "DEF-toe.R"
	};

	private readonly int[] _bones = new int[(int)Bone.Count];
	private readonly int[] _parents = new int[(int)Bone.Count];
	private readonly Transform3D[] _pose = new Transform3D[(int)Bone.Count];
	private readonly Transform3D[] _parentPose = new Transform3D[(int)Bone.Count];
	private Skeleton3D? _skeleton;
	private bool _valid;
	private float _walkEnter = 0.18f, _walkExit = 0.24f;
	private float _glanceChest = 0.45f, _glanceHead = 1.0f;
	private float _counterTurn = 0.09f, _authoredCounter = 0.25f;
	private float _chestLift = 0.05f, _armSwing = 0.34f, _authoredArm = 0.2f;
	private float _tiptoeAfter = 5.0f, _tiptoeCycle = 7.5f, _tiptoeLift = 0.075f, _tiptoePitch = 1.3f;
	private float _speed, _poise = 1.0f, _glance;
	private bool _authoredWalk;
	private float _walkBlend, _idle, _tiptoe;

	public float Speed { get => _speed; set => _speed = value; }
	public float Poise { get => _poise; set => _poise = value; }
	public float Glance { get => _glance; set => _glance = value; }
	public bool AuthoredWalk { get => _authoredWalk; set => _authoredWalk = value; }

	public void Configure(
		float walkEnter, float walkExit, float glanceChest, float glanceHead,
		float counterTurn, float authoredCounter, float chestLift,
		float armSwing, float authoredArm,
		float tiptoeAfter, float tiptoeCycle, float tiptoeLift, float tiptoePitch)
	{
		_walkEnter = Mathf.Max(walkEnter, 0.001f);
		_walkExit = Mathf.Max(walkExit, 0.001f);
		_glanceChest = glanceChest;
		_glanceHead = glanceHead;
		_counterTurn = counterTurn;
		_authoredCounter = authoredCounter;
		_chestLift = chestLift;
		_armSwing = armSwing;
		_authoredArm = authoredArm;
		_tiptoeAfter = tiptoeAfter;
		_tiptoeCycle = Mathf.Max(tiptoeCycle, 0.001f);
		_tiptoeLift = tiptoeLift;
		_tiptoePitch = tiptoePitch;
	}

	public override void _Ready()
	{
		_skeleton = GetSkeleton();
		if (_skeleton == null)
		{
			GD.PushError("GraceMotion: SkeletonModifier3D has no skeleton");
			Active = false;
			return;
		}
		for (int i = 0; i < BoneNames.Length; i++)
		{
			_bones[i] = _skeleton.FindBone(BoneNames[i]);
			if (_bones[i] < 0)
			{
				GD.PushWarning($"GraceMotion: required bone missing: {BoneNames[i]}");
				Active = false;
				return;
			}
			_parents[i] = _skeleton.GetBoneParent(_bones[i]);
		}
		_valid = true;
	}

	public override void _ProcessModificationWithDelta(double delta)
	{
		if (!_valid || _skeleton == null) return;
		float dt = Mathf.Clamp((float)delta, 0.001f, 0.1f);
		for (int i = 0; i < _bones.Length; i++)
		{
			_pose[i] = _skeleton.GetBoneGlobalPose(_bones[i]);
			_parentPose[i] = _parents[i] >= 0 ? _skeleton.GetBoneGlobalPose(_parents[i]) : Transform3D.Identity;
		}

		float target = Mathf.SmoothStep(0.15f, 0.9f, _speed) * (1.0f - Mathf.SmoothStep(1.9f, 2.5f, _speed));
		float duration = target > _walkBlend ? _walkEnter : _walkExit;
		_walkBlend = Mathf.MoveToward(_walkBlend, target, dt / duration);
		float walk = Mathf.SmoothStep(0.0f, 1.0f, _walkBlend) * _poise;
		float reachL = _pose[(int)Bone.ThighL].Basis.Y.Z;
		float reachR = _pose[(int)Bone.ThighR].Basis.Y.Z;
		float legs = Mathf.Clamp((reachL - reachR) / 0.6f, -1.0f, 1.0f);
		_tiptoe = Mathf.MoveToward(_tiptoe, TiptoeTarget(dt), dt * (_speed < 0.15f ? 1.2f : 5.0f));
		float rise = Mathf.SmoothStep(0.0f, 1.0f, _tiptoe);

		Quaternion back = new(Vector3.Up, -_glanceChest * _glance);
		float counterGain = _authoredWalk ? _authoredCounter : 1.0f;
		float armGain = _authoredWalk ? _authoredArm : 1.0f;
		Quaternion counter = new Quaternion(Vector3.Up, _counterTurn * counterGain * legs * walk) * back;
		Quaternion lift = new(Vector3.Right, -(_chestLift + 0.03f * rise) * _poise);
		Turn(Bone.Chest, counter);
		Turn(Bone.UpperChest, lift);
		for (int side = 0; side < 2; side++)
		{
			bool left = side == 0;
			float sign = left ? 1.0f : -1.0f;
			Bone upper = left ? Bone.UpperArmL : Bone.UpperArmR;
			Bone fore = left ? Bone.ForearmL : Bone.ForearmR;
			float swing = _armSwing * armGain * legs * sign * walk;
			float hang = sign * Mathf.DegToRad(-3.0f + 4.0f * rise) * _poise;
			Turn(upper, new Quaternion(Vector3.Back, hang) * new Quaternion(Vector3.Right, swing));
			float ahead = Mathf.Clamp(-legs * sign, 0.0f, 1.0f);
			Turn(fore, new Quaternion(Vector3.Right, -Mathf.DegToRad(5.0f + 16.0f * ahead) * armGain * walk));
		}
		if (rise > 0.001f) RiseOntoToes(rise);
		Quaternion chin = new(Vector3.Right, -0.04f * rise);
		Quaternion look = new(Vector3.Up, -(_glanceChest + _glanceHead) * _glance);
		Turn(Bone.Head, (counter * lift).Inverse() * look * chin);
	}

	private float TiptoeTarget(float delta)
	{
		if (_speed > 0.15f || _poise < 0.99f)
		{
			_idle = 0.0f;
			return 0.0f;
		}
		_idle += delta;
		float into = _idle - _tiptoeAfter;
		if (into < 0.0f) return 0.0f;
		float t = into % _tiptoeCycle;
		if (t < 1.2f) return t / 1.2f;
		if (t < 3.8f) return 1.0f;
		if (t < 5.0f) return 1.0f - (t - 3.8f) / 1.2f;
		return 0.0f;
	}

	private void RiseOntoToes(float rise)
	{
		float height = _tiptoeLift;
		for (int side = 0; side < 2; side++)
		{
			Bone foot = side == 0 ? Bone.FootL : Bone.FootR;
			Bone toe = side == 0 ? Bone.ToeL : Bone.ToeR;
			Vector3 reach = _pose[(int)toe].Origin - _pose[(int)foot].Origin;
			height = Mathf.Min(height, Mathf.Max(reach.Length() * Mathf.Sin(_tiptoePitch) + reach.Y, 0.0f));
		}
		height *= rise;
		Vector3 shift = new(0.0f, height, 0.0f);
		for (int side = 0; side < 2; side++)
		{
			Bone foot = side == 0 ? Bone.FootL : Bone.FootR;
			Bone toe = side == 0 ? Bone.ToeL : Bone.ToeR;
			Vector3 reach = _pose[(int)toe].Origin - _pose[(int)foot].Origin;
			Vector3 across = new(reach.X, 0.0f, reach.Z);
			float drop = Mathf.Min(-reach.Y + height, reach.Length());
			float forward = across.Length() - Mathf.Sqrt(Mathf.Max(reach.LengthSquared() - drop * drop, 0.0f));
			if (across.LengthSquared() > 0.000001f) shift += across.Normalized() * forward * 0.5f;
		}
		int hips = _bones[(int)Bone.Hips];
		Vector3 moved = _parentPose[(int)Bone.Hips].Basis.Inverse() * shift;
		_skeleton!.SetBonePosePosition(hips, _skeleton.GetBonePosePosition(hips) + moved);
		for (int side = 0; side < 2; side++)
		{
			Bone foot = side == 0 ? Bone.FootL : Bone.FootR;
			Bone toe = side == 0 ? Bone.ToeL : Bone.ToeR;
			Vector3 ankle = _pose[(int)foot].Origin;
			Vector3 ball = _pose[(int)toe].Origin;
			Vector3 from = (ball - ankle).Normalized();
			Vector3 to = (ball - ankle - shift).Normalized();
			if (from.Dot(to) > 0.99999f) continue;
			Quaternion pitch = new(from, to);
			Turn(foot, pitch);
			Turn(toe, pitch.Inverse());
		}
	}

	private void Turn(Bone boneIndex, Quaternion rotation)
	{
		if (rotation.IsEqualApprox(Quaternion.Identity)) return;
		int index = (int)boneIndex;
		int bone = _bones[index];
		Quaternion frame = _parentPose[index].Basis.Orthonormalized().GetRotationQuaternion();
		Quaternion local = frame.Inverse() * rotation * frame;
		_skeleton!.SetBonePoseRotation(bone, (local * _skeleton.GetBonePoseRotation(bone)).Normalized());
	}
}
