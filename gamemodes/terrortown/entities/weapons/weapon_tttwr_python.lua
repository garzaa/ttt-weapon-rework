TTTWR.MakePistol(SWEP,
	"python",
	"",
	"357",
	33,
	60 / 150,
	0.015,
	5.5,
	6,
	-4.7, -4.2, 1.5,
	0, -0.25, 0
)


SWEP.ReloadTime = 1.7
SWEP.ReloadTimeConsecutive = 0.7
SWEP.ReloadTimeFinish = 0.4
SWEP.DeployTime = 0.5
SWEP.DeployAnimSpeed = 1.5

SWEP.ReloadAnimSpeed = 1
SWEP.ReloadAnimLoopSpeed = 1.4125
SWEP.ReloadAnimEndSpeed = 0.95
SWEP.ReloadSequence = 8
SWEP.ReloadLoopSequence = 9
SWEP.ReloadEndSequence = 10

SWEP.BulletTracer = 1

SWEP.Primary.ClipMax = 36
SWEP.Primary.Ammo = "AlyxGun"

SWEP.AmmoEnt = "item_ammo_revolver_ttt"

SWEP.NoSetInsertingOnReload = false

SWEP.StoreLastPrimaryFire = true

SWEP.ViewModel = "models/weapons/c_357.mdl"
SWEP.WorldModel = "models/weapons/w_357.mdl"


function SWEP:OnThink()
	local reloading = self:GetReloading()

	if reloading <= 0 then
		return true
	end

	local curtime = CurTime()

	local owner = self:GetOwner()
	if not IsValid(owner) then
		owner = nil
	end

	local clip = self:Clip1()

	local reserve = owner
		and owner.GetAmmoCount
		and owner:GetAmmoCount(self.Primary.Ammo)
		or self.Primary.ClipMax

	if self:GetInserting()
		and curtime > reloading - TTTWR.FrameTime
	then
		self:SetInserting(false)

		if clip < self.Primary.ClipSize
			and reserve > 0
		then
			if owner and owner.RemoveAmmo then
				reserve = reserve - 1
				owner:SetAmmo(reserve, self.Primary.Ammo)
			end

			clip = clip + 1
			self:SetClip1(clip)
		end

		if self.OnInsertClip then
			self:OnInsertClip()
		end
	end

	local fin
	::fin::

	if fin or (
		owner
		and clip > 0
		and owner.KeyDown
		and owner:KeyDown(IN_ATTACK)
	) then
		self:SetReloading(0)
		self:SetInserting(false)

		local vm = owner:GetViewModel()

		if IsValid(vm) then
			vm:SendViewModelMatchingSequence(self.ReloadEndSequence)

			vm:SetPlaybackRate(self.ReloadAnimEndSpeed)
		end

		local nextfire = curtime + self.ReloadTimeFinish

		self:SetNextPrimaryFire(nextfire)
		self:SetNextSecondaryFire(nextfire)

		return true
	end

	if curtime <= reloading then
		return true
	end

	if clip >= self.Primary.ClipSize
		or reserve <= 0
	then
		fin = true
		goto fin
	end

	local relfin = curtime + self.ReloadTimeConsecutive

	self:SetReloading(relfin)

	self:SetNextPrimaryFire(relfin)
	self:SetNextSecondaryFire(relfin)

	local vm = owner and owner:GetViewModel()

	if vm and IsValid(vm) then
		vm:SendViewModelMatchingSequence(self.ReloadLoopSequence)

		vm:SetPlaybackRate(self.ReloadAnimLoopSpeed)
	end

	self:SetInserting(true)

	return true
end

function SWEP:Do3rdPersonReloadAnim(owner)
	owner:DoAnimationEvent(ACT_HL2MP_GESTURE_RELOAD_REVOLVER)
end

local remap, clamp, ease = TTTWR.RemapClamp, math.Clamp, math.EaseInOut

function SWEP:GetPrimaryCone()
	local lastshoot = CurTime() - self:GetLastPrimaryFire()

	local scale = 1

	if lastshoot < 4 / 3 then
		scale = remap(ease(lastshoot * (3 / 4), 0.1, 0), 1, 0, 1, 4)

		if lastshoot < 0.2 then
			scale = scale / (2 - clamp(lastshoot * 5, 0, 1))
		end
	end

	return self.BaseClass.GetPrimaryCone(self) * scale
end

if SERVER then

function SWEP:GetHeadshotMultiplier()
	local lastshoot = CurTime() - self:GetLastPrimaryFire()

	local inmin, inmax, outmin, outmax = 2 / 3, 7 / 6, 1 / 0.66, 1 / 0.33

	if lastshoot > inmax then
		inmin, inmax, outmin, outmax = inmax, 4 / 3, outmax, 1 / 0.22
	end

	return remap(
		lastshoot,
		inmin, inmax,
		outmin, outmax
	)
end

	return
end

-- this makes the recoil animation look less exaggerated
function SWEP:GetViewModelPosition(pos, ang)
	pos, ang = self.BaseClass.GetViewModelPosition(self, pos, ang)

	local cycle

	if self:GetActivity() == ACT_VM_PRIMARYATTACK then
		local owner = self:GetOwner()

		if IsValid(owner) then
			local vm = owner:GetViewModel()

			if IsValid(vm) then
				cycle = vm:GetCycle()
			end
		end
	end

	local offset

	if cycle then
		local inmin, inmax, outmin, outmax = 0.029, 0.44, 1, 0

		if cycle < inmin then
			inmin, inmax, outmin, outmax = 0, inmin, outmax, outmin
		end

		offset = remap(
			cycle, inmin, inmax, outmin, outmax
		)
	end

	if offset and offset ~= 0 then
		ang:RotateAroundAxis(ang:Right(), offset * -27)
		ang:RotateAroundAxis(ang:Forward(), offset * -8)
	end

	pos:Sub(ang:Up())

	return pos, ang
end