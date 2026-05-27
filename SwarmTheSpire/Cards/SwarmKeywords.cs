using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Models;
using STS2RitsuLib;
using STS2RitsuLib.Content;
using STS2RitsuLib.Interop.AutoRegistration;
using STS2RitsuLib.Keywords;
using SwarmTheSpire.Cards;

[RegisterOwnedCardKeyword("harpoon")]
[RegisterOwnedCardKeyword("catch")]
[RegisterOwnedCardTag("harpoon")]
public class SwarmKeywordRegistrar
{
}

public static class SwarmKeywords
{
    private const string HarpoonKey = "harpoon";
    private const string CatchKey = "catch";

    // 直接硬编码，避免 GetQualifiedKeywordId 在运行时返回错误的 ModId
    public const string Harpoon = "SWARM_THE_SPIRE_KEYWORD_HARPOON";
    public const string Catch = "SWARM_THE_SPIRE_KEYWORD_CATCH";

    public static bool IsHarpoon(this CardModel card) =>
        card.HasModKeyword(Harpoon);

    public static bool IsCatch(this CardModel card) =>
        card.HasModKeyword(Catch);
}
