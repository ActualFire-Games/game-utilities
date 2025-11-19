--!strict
--[[
	Types that can be utilized across any module for consistency and maintaining types in a single location.
]]

export type UniversalTimestamp = {
	Year: number,
	Month: number,
	Day: number,
	Hour: number,
	Minute: number,
	Second: number,
	Millisecond: number,
}

export type PlayerJoinData = {
	SourceGameId: number?,
	SourcePlaceId: number?,
	ReferredByPlayerId: number?,
	Members: { number }?, -- Players teleported alongside this player.
	TeleportData: any, -- teleportData specified in original teleport.
	LaunchData: string, -- Plain or JSON econded string containing launch data
	GameJoinContext: {
		JoinSource: Enum.JoinSource,
		ItemType: Enum.AvatarItemType?,
		AssetId: string?,
		OutfitId: string?,
		AssetType: Enum.AssetType?
	}
}

export type AgentParameters = {
	AgentRadius: number?,
	AgentHeight: number?,
	AgentCanJump: boolean?,
	AgentCanClimb: boolean?,
	WaypointSpacing: number?,
	Costs: { [string]: number }?,
	PathSettings: {
		SupportPartialPath: boolean?
	}?
}

export type FollowPathOptions = {
	OnStep: ( (waypoint: PathWaypoint) -> (boolean?) )?,
	OnPathBlocked: ( (blockedWaypointIndex: number, nextWaypointIndex: number) -> () )?,
	OnTimeout: ( (waypoint: PathWaypoint) -> (boolean?) )?,
	MoveTimeout: number?,
	IncludePathBlocked: boolean?, -- default is false since the Blocked event can be finnicky sometimes
}

export type FollowPathResult = {
	ReachedEnd: boolean,
	TimedOut: boolean,
	PathWasBlocked: boolean,
	LastWaypoint: PathWaypoint
}

return {}