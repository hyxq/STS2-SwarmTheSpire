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
    public sealed class KnightsLightsaber()
        : SwarmEvilPoolCard(1, CardType.Attack, CardRarity.Uncommon, TargetType.AnyEnemy, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override bool ShouldGlowGoldInternal
        {
            get
            {
                var combatState = CombatState;
                return combatState != null && combatState.HittableEnemies.Any(e => e.HasPower<MilesPower>());
            }
        }

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<ArtifactPower>(),
            HoverTipFactory.FromPower<MilesPower>(),
        ];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new DamageVar(11m, ValueProp.Move),
             new PowerVar<ArtifactPower>(1m)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            ArgumentNullException.ThrowIfNull(cardPlay.Target);
            await DamageCmd.Attack(DynamicVars.Damage.BaseValue).FromCard(this)
                .Targeting(cardPlay.Target)
                .Execute(choiceContext);

            if (cardPlay.Target.HasPower<MilesPower>())
            {
                await PowerCmd.Apply<ArtifactPower>(choiceContext, Owner.Creature, DynamicVars["ArtifactPower"].BaseValue, Owner.Creature, this, false);
            }
        }

        protected override void OnUpgrade()
        {
            DynamicVars.Damage.UpgradeValueBy(3m);
        }
    }
}