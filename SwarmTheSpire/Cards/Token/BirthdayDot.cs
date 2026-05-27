using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.CardPools;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.Nodes.Vfx;
using MegaCrit.Sts2.Core.ValueProps;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class BirthdayDot()
        : SwarmTokenPoolCard(1, CardType.Skill, CardRarity.Token, TargetType.Self, true)
    {
        public override bool CanBeGeneratedInCombat => false;

        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust, CardKeyword.Ethereal];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
        [
            new DynamicVar("HpLoss", 2m),
            new DynamicVar("StrGain", 2m),
        ];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<StrengthPower>(),
            HoverTipFactory.FromPower<DexterityPower>(),
            HoverTipFactory.FromPower<FrailPower>(),
            HoverTipFactory.FromPower<VulnerablePower>(),
            HoverTipFactory.FromPower<WeakPower>(),
        ];

        public override bool HasTurnEndInHandEffect => true;

        protected override async Task OnTurnEndInHand(PlayerChoiceContext choiceContext)
        {
            await CreatureCmd.Damage(choiceContext, Owner.Creature, DynamicVars["HpLoss"].BaseValue,
                ValueProp.Unblockable, Owner.Creature, this);
            await PowerCmd.Apply<DexterityPower>(choiceContext, Owner.Creature, -DynamicVars["HpLoss"].BaseValue,
                Owner.Creature, this, false);
            await PowerCmd.Apply<StrengthPower>(choiceContext, Owner.Creature, DynamicVars["StrGain"].BaseValue,
                Owner.Creature, this, false);
        }

        public override async Task AfterCardExhausted(PlayerChoiceContext choiceContext, CardModel card,
            bool causedByEthereal)
        {
            if (card != this)
                return;

            TalkCmd.Play(
                new LocString("cards", "SWARM_THE_SPIRE_CARD_BIRTHDAYDOT.exhaustTalk"),
                Owner.Creature,
                VfxColor.Red,
                VfxDuration.Short);

            await PowerCmd.Apply<BirthdayDotExhaustPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this, false);
            await PowerCmd.Apply<AdventTrackingPower>(choiceContext, Owner.Creature, 12m, Owner.Creature, this, false);
        }

        protected override void OnUpgrade() => RemoveKeyword(CardKeyword.Ethereal);

    }
}
