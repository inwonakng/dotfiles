return {
	cmd = { "harper-ls", "--stdio" },
	filetypes = {
		"markdown",
		"tex",
	},
	settings = {
		["harper-ls"] = {
			userDictPath = "",
			fileDictPath = "",
			linters = {
				SpellCheck = true,
				SpelledNumbers = false,
				AnA = true,
				SentenceCapitalization = true,
				UnclosedQuotes = true,
				WrongQuotes = false,
				LongSentences = false,
				RepeatedWords = true,
				Spaces = true,
				Matcher = true,
				CorrectNumberSuffix = true,
			},
			codeActions = {
				ForceStable = false,
			},
			markdown = {
				IgnoreLinkTitle = false,
			},
			diagnosticSeverity = "hint",
			isolateEnglish = false,
		},
	},
}
