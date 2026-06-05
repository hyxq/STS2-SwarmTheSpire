using System.Linq;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Entities.Relics;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Relics;
using MegaCrit.Sts2.Core.Rewards;
using MegaCrit.Sts2.Core.Rooms;
using MegaCrit.Sts2.Core.Runs;
using MegaCrit.Sts2.Core.Saves.Runs;
using STS2RitsuLib.Interop.AutoRegistration;
using STS2RitsuLib.Keywords;
using STS2RitsuLib.RunData;
using SwarmTheSpire.Character;
using SwarmTheSpire.Powers;
using SwarmTheSpire.RunData;

namespace SwarmTheSpire.Relics
{
    [RegisterCharacterStarterRelic(typeof(EvilCharacter))]
    [RegisterTouchOfOrobasRefinement(typeof(WeAreMilesRelic))]
    public class MilesRelic : SwarmRelicTemplate
    {
        public override RelicRarity Rarity => RelicRarity.Starter;

        public override bool ShowCounter => true;

        public override int DisplayAmount =>
            Owner?.RunState is RunState runState
                ? CatchesRunDataEntry.Catches.Get(runState).GlobalCatchesCount + _currentCombatCatches
                : 0;

        protected int _currentCombatCatches;

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<MilesPower>(1m)];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromPower<MilesPower>(),
            HoverTipFactory.FromKeyword(SwarmKeywords.Catch.GetModKeywordCardKeyword()),];

        [SavedProperty]
        public int SavedCatchCount { get; set; }

        public static void TryIncrementCatch(Player player)
        {
            var relic = player.GetRelic<MilesRelic>();
            if (relic == null)
                return;

            relic._currentCombatCatches++;

            var allPlayers = player.Creature?.CombatState?.Allies
                .Select(c => c.Player)
                .Where(p => p != null)
                .Distinct()
                ?? [player];

            foreach (var p in allPlayers)
            {
                var r = p.GetRelic<MilesRelic>();
                if (r != null)
                {
                    r.Flash();
                    r.InvokeDisplayAmountChanged();
                }
            }
        }

        public override async Task BeforeSideTurnStart(PlayerChoiceContext choiceContext, CombatSide side,
            IReadOnlyList<Creature> participants, ICombatState combatState)
        {
            if (side != Owner.Creature.Side || combatState.RoundNumber > 1)
                return;

            _currentCombatCatches = 0;
            InvokeDisplayAmountChanged();
            Flash();
            await PowerCmd.Apply<MilesPower>(choiceContext, combatState.HittableEnemies,
                DynamicVars["MilesPower"].BaseValue, Owner.Creature, null);
        }

        public override async Task AfterObtained()
        {
            if (Owner?.RunState is RunState runState)
            {
                CatchesRunDataEntry.Catches.Modify(runState, data =>
                {
                    data.GlobalCatchesCount = 0;
                });
            }

            InvokeDisplayAmountChanged();
        }

        public override bool TryModifyRewards(Player player, List<Reward> rewards, AbstractRoom? room)
        {
            if (player != Owner || room is null)
                return false;

            var currentCombatCatches = _currentCombatCatches;
            if (currentCombatCatches <= 0)
                return false;

            if (Owner.RunState is not RunState runState)
                return false;

            CatchesRunDataEntry.Catches.Modify(runState, data =>
            {
                data.GlobalCatchesCount += currentCombatCatches;
            });

            _currentCombatCatches = 0;
            SavedCatchCount = CatchesRunDataEntry.Catches.Get(runState).GlobalCatchesCount;
            InvokeDisplayAmountChanged();

            for (var i = 0; i < currentCombatCatches; i++)
            {
                var list = new List<RelicModel>();
                switch (room.RoomType)
                {
                    case RoomType.Monster:
                        list.AddRange(
                        [
                            ModelDb.Relic<RottenFleshRelic>().ToMutable(),
                            ModelDb.Relic<BoneRelic>().ToMutable(),
                            ModelDb.Relic<StringRelic>().ToMutable(),
                            ModelDb.Relic<TropicalFishRelic>().ToMutable(),
                            ModelDb.Relic<RawCodRelic>().ToMutable(),
                            ModelDb.Relic<RawSalmonRelic>().ToMutable(),
                            ModelDb.Relic<SwordOfStone>().ToMutable(),
                        ]);
                        break;
                    case RoomType.Elite:
                        list.AddRange(
                        [
                            ModelDb.Relic<Anchor>().ToMutable(),
                            ModelDb.Relic<HornCleat>().ToMutable(),
                            ModelDb.Relic<BeatingRemnant>().ToMutable(),
                            ModelDb.Relic<NautilusShellRelic>().ToMutable(),
                            ModelDb.Relic<TropicalFishRelic>().ToMutable(),
                            ModelDb.Relic<RawSalmonRelic>().ToMutable(),
                            ModelDb.Relic<RottenFleshRelic>().ToMutable(),
                            ModelDb.Relic<CaptainsWheel>().ToMutable(),
                        ]);
                        break;
                    case RoomType.Boss:
                        list.AddRange(
                        [
                            ModelDb.Relic<WhiteStar>().ToMutable(),
                            ModelDb.Relic<TungstenRod>().ToMutable(),
                            ModelDb.Relic<OldCoin>().ToMutable(),
                        ]);
                        break;
                    default:
                        continue;
                }

                var allowed = list.Where(r => r.IsAllowed(player.RunState)).ToList();
                if (allowed.Count == 0)
                    continue;

                player.PlayerRng.Rewards.Shuffle(allowed);
                Flash();
                var take = Math.Min(1, allowed.Count);
                rewards.AddRange(allowed.Take(take).Select(r => new RelicReward(r, player)));
            }

            return true;
        }

        public override async Task AfterRoomEntered(AbstractRoom room)
        {
            if (Owner?.RunState is RunState runState)
            {
                var catches = CatchesRunDataEntry.Catches.Get(runState);
                if (catches.GlobalCatchesCount < SavedCatchCount)
                {
                    CatchesRunDataEntry.Catches.Modify(runState, data =>
                    {
                        data.GlobalCatchesCount = SavedCatchCount;
                    });
                }
            }

            InvokeDisplayAmountChanged();

            switch (room.RoomType)
            {
                case RoomType.Monster:
                    Flash();
                    await PowerCmd.Apply<MonsterPower>(new ThrowingPlayerChoiceContext(), Owner.Creature, 1m,
                        Owner.Creature, null);
                    break;
                case RoomType.Elite:
                    Flash();
                    await PowerCmd.Apply<ElitePower>(new ThrowingPlayerChoiceContext(), Owner.Creature, 1m,
                        Owner.Creature, null);
                    break;
                case RoomType.Boss:
                    Flash();
                    await PowerCmd.Apply<BossPower>(new ThrowingPlayerChoiceContext(), Owner.Creature, 1m,
                        Owner.Creature, null);
                    break;
            }
        }
    }
}
