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
    func keepsExistingArgumentParsing() {
        let command = JeevesCommandParser.parse("jeeves open browser domain=financial")
        #expect(command != nil)
        #expect(command?.verb == .open)
        #expect(command?.target == "browser")
        #expect(command?.arguments["domain"] == "financial")
    }
}
