using Godot;

/// <summary>Cached in-air and landing pose layer, evaluated after carriage.</summary>
[GlobalClass]
public partial class LeapMotion : SkeletonModifier3D
{
	private enum Bone
	{
		Hips, UpperChest, Head,
		UpperArmL, ForearmL, UpperArmR, ForearmR,
		ThighL, ShinL, FootL, ThighR, ShinR, FootR, Count
	}

	private static readonly string[] BoneNames =
	{
		"DEF-spine", "DEF-spine.004", "DEF-spine.006",
		"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
		"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L",
		"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"
	};

	private readonly int[] _bones = new int[(int)Bone.Count];
	private readonly int[] _parents = new int[(int)Bone.Count];
	private readonly Transform3D[] _pose = new Transform3D[(int)Bone.Count];
	private readonly Transform3D[] _parentPose = new Transform3D[(int)Bone.Count];
	private Skeleton3D? _skeleton;
	private bool _valid;
	private float _modelScale = 0.8f;
	private float _dipDepth = 0.03f, _dipDrop = 0.15f, _dipFrequency = 20.0f, _dipDamping = 0.6f, _dipLean = 0.8f;
	private float _split = 0.35f, _point = 0.5f, _arms = 0.45f, _chest = 0.08f;
	private float _amount, _progress, _dip, _dipSpeed;
	private bool _leadLeft = true, _dipLeft = true;

	public float Amount { get => _amount; set => _amount = value; }
	public float Progress { get => _progress; set => _progress = value; }
	public bool LeadLeft { get => _leadLeft; set => _leadLeft = value; }

	public void Configure(float modelScale, float dipDepth, float dipDrop, float dipFrequency, float dipDamping,
		float dipLean, float split, float point, float arms, float chest)
	{
		_modelScale = Mathf.Max(modelScale, 0.001f);
		_dipDepth = dipDepth;
		_dipDrop = dipDrop;
		_dipFrequency = dipFrequency;
		_dipDamping = dipDamping;
		_dipLean = dipLean;
		_split = split;
		_point = point;
		_arms = arms;
		_chest = chest;
	}

	public override void _Ready()
	{
		_skeleton = GetSkeleton();
		if (_skeleton == null)
		{
			GD.PushError("LeapMotion: SkeletonModifier3D has no skeleton");
			Active = false;
			return;
		}
		for (int i = 0; i < BoneNames.Length; i++)
		{
			_bones[i] = _skeleton.FindBone(BoneNames[i]);
			if (_bones[i] < 0)
			{
				GD.PushWarning($"LeapMotion: required bone missing: {BoneNames[i]}");
				Active = false;
				return;
			}
			_parents[i] = _skeleton.GetBoneParent(_bones[i]);
		}
		_valid = true;
	}

	public void Dip(float power, bool left)
	{
		_dipLeft = left;
		float depth = Mathf.Lerp(_dipDepth, _dipDrop, power);
		_dipSpeed = 2.0f * depth * _dipFrequency;
	}

	public override void _ProcessModificationWithDelta(double delta)
	{
		if (!_valid || _skeleton == null) return;
		float dt = Mathf.Clamp((float)delta, 0.001f, 0.1f);
		Spring(dt);
		float crouch = Mathf.Max(_dip, 0.0f);
		if (_amount <= 0.001f && crouch <= 0.0005f) return;
		for (int i = 0; i < _bones.Length; i++)
		{
			_pose[i] = _skeleton.GetBoneGlobalPose(_bones[i]);
			_parentPose[i] = _parents[i] >= 0 ? _skeleton.GetBoneGlobalPose(_parents[i]) : Transform3D.Identity;
		}
		if (_amount > 0.001f) HoldLine();
		if (crouch > 0.0005f) Crouch(crouch);
	}

	private void Spring(float delta)
	{
		int steps = Mathf.Max(1, Mathf.CeilToInt(delta * 240.0f));
		float h = delta / steps;
		float w = _dipFrequency;
		for (int i = 0; i < steps; i++)
		{
			_dipSpeed += (-w * w * _dip - 2.0f * _dipDamping * w * _dipSpeed) * h;
			_dip += _dipSpeed * h;
		}
	}

	private void HoldLine()
	{
		float p = Mathf.Clamp(_progress, 0.0f, 1.0f);
		float swell = _amount * Mathf.Sin(Mathf.Pi * Mathf.Clamp(p / 0.8f, 0.0f, 1.0f));
		float split = _split * swell;
		float straighten = 0.7f * swell;
		float pointTrail = _point * _amount;
		float pointLead = _point * _amount * Mathf.Lerp(1.0f, 0.25f, Mathf.SmoothStep(0.75f, 1.0f, p));
		float armLine = _arms * swell;
		float chestLift = _chest * _amount * (1.0f - Mathf.SmoothStep(0.8f, 1.0f, p));
		Bone leadThigh = _leadLeft ? Bone.ThighL : Bone.ThighR;
		Bone trailThigh = _leadLeft ? Bone.ThighR : Bone.ThighL;
		Bone trailShin = _leadLeft ? Bone.ShinR : Bone.ShinL;
		Bone trailFoot = _leadLeft ? Bone.FootR : Bone.FootL;
		Bone leadFoot = _leadLeft ? Bone.FootL : Bone.FootR;
		Turn(leadThigh, new Quaternion(Vector3.Right, -split));
		Turn(trailThigh, new Quaternion(Vector3.Right, split));
		Vector3 thigh = _pose[(int)trailThigh].Basis.Y.Normalized();
		Vector3 shin = _pose[(int)trailShin].Basis.Y.Normalized();
		if (thigh.Dot(shin) < 0.9999f)
			Turn(trailShin, Quaternion.Identity.Slerp(new Quaternion(shin, thigh), straighten));
		Turn(trailFoot, new Quaternion(Vector3.Right, pointTrail));
		Turn(leadFoot, new Quaternion(Vector3.Right, pointLead));
		for (int side = 0; side < 2; side++)
		{
			bool left = side == 0;
			float outward = left ? 1.0f : -1.0f;
			bool forward = left == !_leadLeft;
			Bone upper = left ? Bone.UpperArmL : Bone.UpperArmR;
			Bone fore = left ? Bone.ForearmL : Bone.ForearmR;
			float swing = forward ? -armLine : armLine * 0.8f;
			float open = outward * armLine * (forward ? 0.25f : 0.45f);
			Turn(upper, new Quaternion(Vector3.Back, open) * new Quaternion(Vector3.Right, swing));
			Turn(fore, new Quaternion(Vector3.Right, Mathf.DegToRad(forward ? -18.0f : -6.0f) * _amount));
		}
		Quaternion lift = new(Vector3.Right, -chestLift);
		Turn(Bone.UpperChest, lift);
		Turn(Bone.Head, lift.Inverse());
	}

	private void Crouch(float depth)
	{
		float drop = depth / _modelScale;
		int hips = _bones[(int)Bone.Hips];
		Vector3 moved = _parentPose[(int)Bone.Hips].Basis.Inverse() * new Vector3(0.0f, -drop, 0.0f);
		_skeleton!.SetBonePosePosition(hips, _skeleton.GetBonePosePosition(hips) + moved);
		Bone thigh = _dipLeft ? Bone.ThighL : Bone.ThighR;
		Bone shin = _dipLeft ? Bone.ShinL : Bone.ShinR;
		Bone foot = _dipLeft ? Bone.FootL : Bone.FootR;
		Vector3 hipAt = _pose[(int)thigh].Origin;
		Vector3 kneeAt = _pose[(int)shin].Origin;
		Vector3 ankleAt = _pose[(int)foot].Origin;
		float fold = KneeFold(hipAt.DistanceTo(kneeAt), kneeAt.DistanceTo(ankleAt), hipAt.DistanceTo(ankleAt), drop);
		Turn(thigh, new Quaternion(Vector3.Right, -fold * 0.5f));
		Turn(shin, new Quaternion(Vector3.Right, fold));
		Turn(foot, new Quaternion(Vector3.Right, -fold * 0.5f));
		Quaternion tip = new(Vector3.Right, _dipLean * depth);
		Turn(Bone.UpperChest, tip);
		Turn(Bone.Head, tip.Inverse());
	}

	private float KneeFold(float a, float b, float span, float drop)
	{
		float lo = Mathf.Abs(a - b) + 0.001f;
		float hi = a + b - 0.001f;
		float currentSpan = Mathf.Clamp(span, lo, hi);
		float nextSpan = Mathf.Clamp(span - drop, lo, hi);
		float now = Mathf.Acos(Mathf.Clamp((a * a + b * b - currentSpan * currentSpan) / (2.0f * a * b), -1.0f, 1.0f));
		float next = Mathf.Acos(Mathf.Clamp((a * a + b * b - nextSpan * nextSpan) / (2.0f * a * b), -1.0f, 1.0f));
		return now - next;
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
