import Testing
@testable import jeeves

struct JeevesCommandParserTests {

    @Test
    func parsesWhyPhraseCommand() {
        let command = JeevesCommandParser.parse("jeeves why this screen")
        #expect(command != nil)
        #expect(command?.verb == .why)
        #expect(command?.target == "this")
        #expect(command?.modifiers == ["screen"])
        #expect(command?.targetPhrase == "this screen")
    }

    @Test
    func parsesWhatMatchedCommand() {
        let command = JeevesCommandParser.parse("jeeves what matched")
        #expect(command != nil)
        #expect(command?.verb == .what)
        #expect(command?.target == "matched")
        #expect(command?.modifiers == [])
        #expect(command?.targetPhrase == "matched")
    }

    @Test
    func parsesRecentDecisionsCommand() {
        let command = JeevesCommandParser.parse("jeeves recent decisions")
        #expect(command != nil)
        #expect(command?.verb == .recent)
        #expect(command?.target == "decisions")
        #expect(command?.targetPhrase == "decisions")
    }

    @Test
    func parsesShowRecentPolicyChecksCommand() {
        let command = JeevesCommandParser.parse("jeeves show recent policy checks")
        #expect(command != nil)
        #expect(command?.verb == .show)
        #expect(command?.target == "recent")
        #expect(command?.modifiers == ["policy", "checks"])
        #expect(command?.targetPhrase == "recent policy checks")
    }

    @Test
    func parsesExecutionAwarenessQueries() {
        let canDo = JeevesCommandParser.parse("jeeves what can i do")
        #expect(canDo?.verb == .what)
        #expect(canDo?.targetPhrase == "can i do")

        let recommend = JeevesCommandParser.parse("jeeves why do you recommend this")
        #expect(recommend?.verb == .why)
        #expect(recommend?.targetPhrase == "do you recommend this")

        let evidence = JeevesCommandParser.parse("jeeves what evidence supports this")
        #expect(evidence?.verb == .what)
        #expect(evidence?.targetPhrase == "evidence supports this")
    }

    @Test
    func keepsExistingArgumentParsing() {
        let command = JeevesCommandParser.parse("jeeves open browser domain=financial")
        #expect(command != nil)
        #expect(command?.verb == .open)
        #expect(command?.target == "browser")
        #expect(command?.arguments["domain"] == "financial")
    }
}
