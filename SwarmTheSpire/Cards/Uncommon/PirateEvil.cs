using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.ValueProps;
using STS2RitsuLib.CardTags;
using SwarmTheSpire;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class PirateEvil()
        : SwarmEvilPoolCard(1, CardType.Attack, CardRarity.Uncommon, TargetType.AnyEnemy, true)
    {
        protected override HashSet<CardTag> CanonicalTags => [SwarmCardTagIds.Evz.GetModCardTag()];

        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override bool ShouldGlowGoldInternal
        {
            get
            {
                var combatState = CombatState;
                return combatState != null && combatState.HittableEnemies.Any(e => e.HasPower<WeakPower>());
            }
        }

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<WeakPower>(),
            HoverTipFactory.FromPower<MilesPower>(),
        ];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new DamageVar(8m, ValueProp.Move)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            ArgumentNullException.ThrowIfNull(cardPlay.Target);
            var wasTargetWeak = cardPlay.Target.HasPower<WeakPower>();
            var hitCount = wasTargetWeak ? 2 : 1;

            var val = await DamageCmd.Attack(DynamicVars.Damage.BaseValue).WithHitCount(hitCount).FromCard(this)
                .Targeting(cardPlay.Target)
                .Execute(choiceContext);

            if (cardPlay.Target.HasPower<MilesPower>())
            {
                var actualDamage = val.Results.SelectMany(static r => r).Sum(static r => r.TotalDamage + r.OverkillDamage);
                await PlayerCmd.GainGold(actualDamage, Owner);
            }
        }

        protected override void OnUpgrade()
        {
            DynamicVars.Damage.UpgradeValueBy(2m);
        }
    }
}