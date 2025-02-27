local _, core = ...;
local _G = _G;
local MonDKP = core.MonDKP;
local L = core.L;

local function ZeroSumDistribution()
	if core.CurrentlySyncing then
		StaticPopupDialogs["CURRENTLY_SYNC"] = {
			text = "|CFFFF0000"..L["WARNING"].."|r: "..L["CurrentlySyncing"],
			button1 = L["OK"],
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show ("CURRENTLY_SYNC")
		return;
	end
	if IsInRaid() then
		local curTime = time();
		local distribution;
		local reason = MonDKP_DB.bossargs.CurrentRaidZone..": "..MonDKP_DB.bossargs.LastKilledBoss
		local players = "";
		local VerifyTable = {};

		if MonDKP_DB.modes.ZeroSumStandby then
			for i=1, #MonDKP_Standby do
				tinsert(VerifyTable, MonDKP_Standby[i].player)
			end
		end		

		for i=1, 40 do
			local tempName = GetRaidRosterInfo(i)
			local search = MonDKP:Table_Search(VerifyTable, tempName)
			local search2 = MonDKP:Table_Search(MonDKP_DKPTable, tempName)

			if not search and search2 then
				tinsert(VerifyTable, tempName)
			end
		end

		distribution = MonDKP_round(MonDKP_DB.modes.ZeroSumBank.balance / #VerifyTable, MonDKP_DB.modes.rounding) + MonDKP_DB.modes.Inflation

		for i=1, #VerifyTable do
			local name = VerifyTable[i]
			local search = MonDKP:Table_Search(MonDKP_DKPTable, name)

			if search then
				MonDKP_DKPTable[search[1][1]].dkp = MonDKP_DKPTable[search[1][1]].dkp + distribution
				players = players..name..","
			end
		end
		
		MonDKP:SeedVerify_Update()
		if core.UpToDate and core.IsOfficer then -- updates seeds only if table is currently up to date.
			MonDKP:UpdateSeeds()
		end
		tinsert(MonDKP_DKPHistory, {players=players, dkp=distribution, reason=reason, date=curTime})
		MonDKP.Sync:SendData("MonDKPDataSync", MonDKP_DKPTable)
		if MonDKP.ConfigTab6.history then
			MonDKP:DKPHistory_Reset()
		end
		MonDKP:DKPHistory_Update()
		local temp_table = {}
		tinsert(temp_table, {seed = MonDKP_DKPHistory.seed, {players=players, dkp=distribution, reason=reason, date=curTime}})
		MonDKP.Sync:SendData("MonDKPDKPAward", temp_table[1])
		table.wipe(temp_table)
		MonDKP.Sync:SendData("MonDKPBroadcast", L["RaidDKPAdjustBy"].." "..distribution.." "..L["Among"].." "..#VerifyTable.." "..L["PlayersForReason"]..": "..reason)
		MonDKP:Print("Raid DKP Adjusted by "..distribution.." "..L["Among"].." "..#VerifyTable.." "..L["PlayersForReason"]..": "..reason)
		
		table.wipe(VerifyTable)
		table.wipe(MonDKP_DB.modes.ZeroSumBank)
		MonDKP_DB.modes.ZeroSumBank.balance = 0
		core.ZeroSumBank.LootFrame.LootList:SetText("")
		DKPTable_Update()
		MonDKP.Sync:SendData("MonDKPZeroSum", MonDKP_DB.modes.ZeroSumBank)
		MonDKP:ZeroSumBank_Update()
		core.ZeroSumBank:Hide();
	else
		MonDKP:Print(L["NotInRaidParty"])
	end
end

function MonDKP:ZeroSumBank_Update()
	core.ZeroSumBank.Boss:SetText(MonDKP_DB.bossargs.LastKilledBoss.." in "..MonDKP_DB.bossargs.CurrentRaidZone)
	core.ZeroSumBank.Balance:SetText(MonDKP_DB.modes.ZeroSumBank.balance)

	for i=1, #MonDKP_DB.modes.ZeroSumBank do
 		if i==1 then
 			core.ZeroSumBank.LootFrame.LootList:SetText(MonDKP_DB.modes.ZeroSumBank[i].loot.." "..L["For"].." "..MonDKP_DB.modes.ZeroSumBank[i].cost.." "..L["DKP"].."\n")
 		else
 			core.ZeroSumBank.LootFrame.LootList:SetText(core.ZeroSumBank.LootFrame.LootList:GetText()..MonDKP_DB.modes.ZeroSumBank[i].loot.." "..L["For"].." "..MonDKP_DB.modes.ZeroSumBank[i].cost.." "..L["DKP"].."\n")
 		end
 	end
 	
 	if core.ZeroSumBank.LootFrame.LootList:GetHeight() > 180 then
 		core.ZeroSumBank.LootFrame:SetHeight(core.ZeroSumBank.LootFrame.LootList:GetHeight() + 18)
 		core.ZeroSumBank:SetHeight(350 + core.ZeroSumBank.LootFrame.LootList:GetHeight() - 170)
 	end
end

function MonDKP:ZeroSumBank_Create()
	local f = CreateFrame("Frame", "MonDKP_DKPZeroSumBankFrame", UIParent, "ShadowOverlaySmallTemplate");

	if not MonDKP_DB.modes.ZeroSumBank then MonDKP_DB.modes.ZeroSumBank = 0 end

	f:SetPoint("TOP", UIParent, "TOP", 400, -50);
	f:SetSize(325, 350);
	f:SetBackdrop( {
		bgFile = "Textures\\white.blp", tile = true,                -- White backdrop allows for black background with 1.0 alpha on low alpha containers
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 3,  
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	});
	f:SetBackdropColor(0,0,0,0.9);
	f:SetBackdropBorderColor(1,1,1,1)
	f:SetFrameStrata("FULLSCREEN")
	f:SetFrameLevel(20)
	f:SetMovable(true);
	f:EnableMouse(true);
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", f.StartMoving);
	f:SetScript("OnDragStop", f.StopMovingOrSizing);
	f:Hide()

	-- Close Button
	f.closeContainer = CreateFrame("Frame", "MonDKPZeroSumBankWindowCloseButtonContainer", f)
	f.closeContainer:SetPoint("CENTER", f, "TOPRIGHT", -4, 0)
	f.closeContainer:SetBackdrop({
		bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 3, 
	});
	f.closeContainer:SetBackdropColor(0,0,0,0.9)
	f.closeContainer:SetBackdropBorderColor(1,1,1,0.2)
	f.closeContainer:SetSize(28, 28)

	f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.closeBtn:SetPoint("CENTER", f.closeContainer, "TOPRIGHT", -14, -14)

	f.BankHeader = f:CreateFontString(nil, "OVERLAY")
	f.BankHeader:SetFontObject("MonDKPLargeLeft");
	f.BankHeader:SetScale(1)
	f.BankHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10);
	f.BankHeader:SetText(L["ZeroSumBank"])

	f.Boss = f:CreateFontString(nil, "OVERLAY")
	f.Boss:SetFontObject("MonDKPSmallLeft");
	f.Boss:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -45);

	f.Boss.Header = f:CreateFontString(nil, "OVERLAY")
	f.Boss.Header:SetFontObject("MonDKPLargeRight");
	f.Boss.Header:SetScale(0.7)
	f.Boss.Header:SetPoint("RIGHT", f.Boss, "LEFT", -7, 0);
	f.Boss.Header:SetText(L["Boss"]..": ")

	f.Balance = CreateFrame("EditBox", nil, f)
	f.Balance:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -65)   
    f.Balance:SetAutoFocus(false)
    f.Balance:SetMultiLine(false)
    f.Balance:SetSize(85, 28)
    f.Balance:SetBackdrop({
      bgFile   = "Textures\\white.blp", tile = true,
      edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\slider-border", tile = true, tileSize = 1, edgeSize = 2, 
    });
    f.Balance:SetBackdropColor(0,0,0,0.9)
    f.Balance:SetBackdropBorderColor(1,1,1,0.4)
    f.Balance:SetMaxLetters(10)
    f.Balance:SetTextColor(1, 1, 1, 1)
    f.Balance:SetFontObject("MonDKPSmallLeft")
    f.Balance:SetTextInsets(10, 10, 5, 5)
    f.Balance:SetScript("OnEscapePressed", function(self)    -- clears focus on esc
      self:ClearFocus()
    end)
    f.Balance:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(L["ZeroSumBalance"], 0.25, 0.75, 0.90, 1, true);
		GameTooltip:AddLine(L["ZeroSumBalanceTTDesc"], 1.0, 1.0, 1.0, true);
		GameTooltip:Show();
	end)
	f.Balance:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	f.Balance.Header = f:CreateFontString(nil, "OVERLAY")
	f.Balance.Header:SetFontObject("MonDKPLargeRight");
	f.Balance.Header:SetScale(0.7)
	f.Balance.Header:SetPoint("RIGHT", f.Balance, "LEFT", -7, 0);
	f.Balance.Header:SetText(L["Balance"]..": ")

	f.Distribute = CreateFrame("Button", "MonDKPBiddingDistributeButton", f, "MonolithDKPButtonTemplate")
	f.Distribute:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -95);
	f.Distribute:SetSize(90, 25);
	f.Distribute:SetText(L["DistributeDKP"]);
	f.Distribute:GetFontString():SetTextColor(1, 1, 1, 1)
	f.Distribute:SetNormalFontObject("MonDKPSmallCenter");
	f.Distribute:SetHighlightFontObject("MonDKPSmallCenter");
	f.Distribute:SetScript("OnClick", function (self)
		if MonDKP_DB.modes.ZeroSumBank.balance > 0 then
			StaticPopupDialogs["CONFIRM_ADJUST1"] = {
				text = L["DistributeAllDKPConf"],
				button1 = L["YES"],
				button2 = L["NO"],
				OnAccept = function()
					ZeroSumDistribution()
				end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show ("CONFIRM_ADJUST1")
		else
			MonDKP:Print(L["NoPointsToDistribute"])
		end
	end)
	f.Distribute:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(L["DistributeDKP"], 0.25, 0.75, 0.90, 1, true);
		GameTooltip:AddLine(L["DistrubuteBanked"], 1.0, 1.0, 1.0, true);
		GameTooltip:Show();
	end)
	f.Distribute:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	-- Include Standby Checkbox
	if not MonDKP_DB.modes.ZeroSumStandby then MonDKP_DB.modes.ZeroSumStandby = false end
	f.IncludeStandby = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate");
	f.IncludeStandby:SetChecked(MonDKP_DB.modes.ZeroSumStandby)
	f.IncludeStandby:SetScale(0.6);
	f.IncludeStandby.text:SetText("  |cff5151de"..L["IncludeStandby"].."|r");
	f.IncludeStandby.text:SetScale(1.5);
	f.IncludeStandby.text:SetFontObject("MonDKPSmallLeft")
	f.IncludeStandby:SetPoint("TOPLEFT", f.Distribute, "BOTTOMLEFT", -15, -10);
	f.IncludeStandby:SetScript("OnClick", function(self)
		MonDKP_DB.modes.ZeroSumStandby = self:GetChecked();
		PlaySound(808)
	end)
	f.IncludeStandby:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(L["IncludeStandbyList"], 0.25, 0.75, 0.90, 1, true);
		GameTooltip:AddLine(L["IncStandbyListTTDesc"], 1.0, 1.0, 1.0, true);
		GameTooltip:AddLine(L["IncStandbyListTTWarn"], 1.0, 0, 0, true);
		GameTooltip:Show();
	end)
	f.IncludeStandby:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	-- Loot List Frame
	f.LootFrame = CreateFrame("Frame", "MonDKPZeroSumBankLootListContainer", f, "ShadowOverlaySmallTemplate")
	f.LootFrame:SetPoint("TOPRIGHT", f.IncludeStandby, "BOTTOM", 95, -5)
	f.LootFrame:SetSize(305, 190)
	f.LootFrame:SetBackdrop({
		bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 3, 
	});
	f.LootFrame:SetBackdropColor(0,0,0,0.9)
	f.LootFrame:SetBackdropBorderColor(1,1,1,1)

	f.LootFrame.Header = f.LootFrame:CreateFontString(nil, "OVERLAY")
	f.LootFrame.Header:SetFontObject("MonDKPLargeLeft");
	f.LootFrame.Header:SetScale(0.7)
	f.LootFrame.Header:SetPoint("TOPLEFT", f.LootFrame, "TOPLEFT", 8, -8);
	f.LootFrame.Header:SetText(L["LootBanked"])

	f.LootFrame.LootList = f.LootFrame:CreateFontString(nil, "OVERLAY")
	f.LootFrame.LootList:SetFontObject("MonDKPNormalLeft");
	f.LootFrame.LootList:SetPoint("TOPLEFT", f.LootFrame, "TOPLEFT", 8, -18);
	f.LootFrame.LootList:SetText("")

	return f
end