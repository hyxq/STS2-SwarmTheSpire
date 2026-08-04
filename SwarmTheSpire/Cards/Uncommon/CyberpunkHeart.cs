using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Powers;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class CyberpunkHeart()
        : SwarmEvilPoolCard(1, CardType.Power, CardRarity.Uncommon, TargetType.Self, true)
    {

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<ArtifactPower>(),
            HoverTipFactory.FromPower<RegenPower>(),
        ];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<ArtifactPower>(2m),
             new PowerVar<CyberpunkHeartPower>(1m)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<ArtifactPower>(choiceContext, Owner.Creature, DynamicVars["ArtifactPower"].BaseValue,
                Owner.Creature, this, false);

            await PowerCmd.Apply<CyberpunkHeartPower>(choiceContext, Owner.Creature,
                DynamicVars["CyberpunkHeartPower"].BaseValue, Owner.Creature, this, false);
        }

        protected override void OnUpgrade() => DynamicVars["ArtifactPower"].UpgradeValueBy(1m);
    }
}
