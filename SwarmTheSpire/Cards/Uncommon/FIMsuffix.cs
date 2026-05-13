using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Interop.AutoRegistration;
using SwarmTheSpire;

namespace SwarmTheSpire.Cards
{
    public sealed class FimSuffix()
        : SwarmEvilPoolCard(1, CardType.Skill, CardRarity.Uncommon, TargetType.Self, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override void OnUpgrade() => RemoveKeyword(CardKeyword.Exhaust);
    }
}
