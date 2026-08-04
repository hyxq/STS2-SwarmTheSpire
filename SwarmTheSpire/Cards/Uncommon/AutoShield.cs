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
    public sealed class AutoShield()
        : SwarmEvilPoolCard(2, CardType.Skill, CardRarity.Uncommon, TargetType.Self, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<ArtifactPower>(),
            HoverTipFactory.FromPower<BufferPower>(),
        ];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<ArtifactPower>(1m),
             new PowerVar<AutoShieldPower>(1m)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<ArtifactPower>(choiceContext, Owner.Creature, DynamicVars["ArtifactPower"].BaseValue,
                Owner.Creature, this, false);

            await PowerCmd.Apply<AutoShieldPower>(choiceContext, Owner.Creature, DynamicVars["AutoShieldPower"].BaseValue, Owner.Creature, this, false);
        }

        protected override void OnUpgrade() => RemoveKeyword(CardKeyword.Exhaust);
    }
}
