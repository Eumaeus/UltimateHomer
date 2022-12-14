### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ 4fbd0098-5b2e-11ed-1a87-11df2c7d3e12
begin
	using Unicode
	using PolytonicGreek
	using SplitApplyCombine
	using CitableBase
	using CitableText
	using CitableCorpus
	using CitableObject
	using EzXML
end

# ╔═╡ 631f349a-e339-4dca-94e2-19234c92c79f


# ╔═╡ 7caf2ece-3164-431c-9d4b-00a89b691271
md"""#### Set up and do a little testing on loading an XML Syntax file"""

# ╔═╡ 4d074d84-84ac-479b-b048-fe9833e06c69
iliadTBString = read("treebanks/iliad_all.xml", String)

# ╔═╡ 560adbd8-1316-4ae4-b1b8-72aac8ef5bfa
iliadXML = parsexml(iliadTBString)

# ╔═╡ ad54a5ad-3021-421b-94a7-78b62e9e4158
tbRoot = root(iliadXML)

# ╔═╡ a15ddf82-1141-45a7-b382-0cf0fbfe3cdb
iliadSents = findall("//sentence", iliadXML)

# ╔═╡ 15cc96d6-327c-45f8-a40e-c55268eca05b
println(length(iliadSents))

# ╔═╡ 87dbb837-a07b-4579-b1b7-59544ab61400
md"""
## We need a data `Struct` to hold stuff.
"""

# ╔═╡ 3dc1b3f5-d60b-4427-841d-6c218b8c94a9
md"""We will change the `index` properties to `Int64` when we're done testing."""

# ╔═╡ 15263e0a-3566-4e55-8352-a08b22ba7461
md"""
Let's serialize an EpicToken record to tabular format.
"""

# ╔═╡ f967e8b2-9ed9-4636-8365-7acd5337ec5b
md"""The below generate a header-row, tab-separated"""

# ╔═╡ 035ca287-1f81-44c4-9929-688a58386a74
function tabularEpicTokenHeader()
	"Urn	tokenIndex	tokenCtsUrn	surfaceForm	passageCtsUrn	sentenceUrn	sentenceSpanUrn	lemmaString	lexUrn	posTag	headIndex	headUrn	relationAbbr	relationUrn	relationLabel	speakerLabel	speakerUrn	morphLabel	POSUrn	POSLabel	numberUrn	numberLabel	tenseUrn	tenseLabel	moodUrn	moodLabel	voiceUrn	voiceLabel	genderUrn	genderLabel	grammaticalCaseUrn	grammaticalCaseLabel	degreeUrn	degreeLabel"
end

# ╔═╡ fcf317b0-6dd2-42c6-8713-3facf3cff9b1
tabularEpicTokenHeader()

# ╔═╡ 192eb118-57a4-4209-ad84-fab8b5693159
md"""
### Process XML!
"""

# ╔═╡ 944cc2d5-6be8-4e71-b9bf-b3a4f8e766a8
md"""**First Pass** We grab the easy stuff from the XML attributes."""

# ╔═╡ db78845e-9134-4a05-a2a0-ea8492027918
md"""#### Another mapping to get the token-index in place, and to deal with empty Citations."""


# ╔═╡ 858378c7-cd4c-41cd-93fc-106a6af3e432
md"""
Do a "zip-with-index" on the whole thing, and use that to populate the tokenIndex property.
"""

# ╔═╡ 4b5ac42f-f211-4d45-a6ea-ce2c25c8260d
md"""

### Fill In Missing CTS URNs

We assume that missing `canonicalCitation` records are punctuation. We assume that no *Iliad* line begins with punctuation, so each punctuation mark must have the same CTS-URN as the *preceding* token.

"""

# ╔═╡ 3679562c-964a-481f-8a5c-d873070b0b47
md"""We now want to add token-level CtsUrns in the `tokenCitation` property. We'll start by generating, from the data, a Vector of all valid CtsUrns (at the edition-level, book + line)."""

# ╔═╡ 2017ef58-a1b4-4429-85e3-54d5f10f0af0
md"""
	The below works, but takes a **long** time. So we'll disable it for now, and generate those URNs as the last step. No need to be re-doing it with every update.
"""

# ╔═╡ 744f91eb-b548-4090-b2fb-4620bb373fcb
#=
withTokenLevelUrns = map(Iterators.take(validUrns, 1000)) do u
	lineTokens = filter(iliadTokenVec3) do t
		t.canonicalCitation == u
	end
	map(collect(enumerate(lineTokens))) do (i, t)
		t.tokenCitation = CtsUrn(string(t.canonicalCitation) * ".$i" )
		t
	end 
end |> Iterators.flatten |> collect
=#

# ╔═╡ 857ecb3a-e195-4859-bddb-6821ae03b3fa
md"""
### Work with the morphology of each token!

This will require some tests, because I think we have a lot of bad data.
"""

# ╔═╡ 867cc35d-f364-4a1b-83a2-6c9283e41250
md"""If the above works, we are good!"""

# ╔═╡ 5079fb39-7c46-4421-95dd-88371c8ff72f
md"""
## Morphology Stuff Below!
"""

# ╔═╡ 8ead2580-0275-4ba9-a500-790ad58a72f0
md"""#### We create a basic `struct` to hold the versions of a pos-element we want"""

# ╔═╡ a23071ce-7184-44dd-a423-9465e4aacd7e
Base.@kwdef mutable struct MorphRecord
	posTag::String = ""
	short::String = ""
	long::String = ""
	urnString::String = ""
end

# ╔═╡ e3c5b465-37e8-43ba-8aa8-870321a559df
md""" 

**Overriding Equality!** The two functions below are necessary for us to compare `MorphRecord` objects. 

"""

# ╔═╡ 7b0f510a-4a21-49cd-b80c-4aac003c713c
function Base.:(==)(mr1::MorphRecord, mr2::MorphRecord)
	if ((mr1.posTag == mr2.posTag) &&
		(mr1.short == mr2.short) &&
		(mr1.long == mr2.long) &&
		(mr1.urnString == mr2.urnString))
	
		true
	else
		false
	end
end

# ╔═╡ 2af42b75-4b13-4314-85f9-1df91968bfa1
function isequal(mr1::MorphRecord, mr2::MorphRecord)
	if ((mr1.posTag == mr2.posTag) &&
		(mr1.short == mr2.short) &&
		(mr1.long == mr2.long) &&
		(mr1.urnString == mr2.urnString) 
	)
	
		true
	else
		false
	end
	
end

# ╔═╡ 11b3f65f-3062-4ff2-ae7a-227d14f21f07
md"""#### Let's set up some constants here, which we can use repeatedly"""

# ╔═╡ efe42e6d-d20f-44d6-9706-946c63f400c5
begin
	# Null values
	const nullUrn = Cite2Urn("urn:cite2:fuFolio:uh.2022:null")
	const emptyMorphRecord = MorphRecord("", "", "", "")

	# Keeping track of indices for POStag parts
	posNum = 1
	personNum = 2
	numberNum = 3
	tenseNum = 4
	moodNum = 5
	voiceNum = 6
	genderNum = 7
	caseNum = 8
	degreeNum = 9

	nothing
end

# ╔═╡ 1ac5df9c-870d-4985-b1c7-b924c59aa673
md""" ### Morphology Struct
"""

# ╔═╡ ad6a60bb-a15f-41ee-b335-69fc46239c0d
md"""
We make a Struct for morphology, with default value as `emptyMorphRecord`, since no form is going to have *all* properties.
"""

# ╔═╡ e11f6ef9-7624-44e5-adf4-453e685b8c07
Base.@kwdef mutable struct Morphology
	pos::MorphRecord = emptyMorphRecord
	person::MorphRecord = emptyMorphRecord
	number::MorphRecord = emptyMorphRecord
	voice::MorphRecord = emptyMorphRecord
	mood::MorphRecord = emptyMorphRecord
	tense::MorphRecord = emptyMorphRecord
	gender::MorphRecord = emptyMorphRecord
	grammaticalCase::MorphRecord = emptyMorphRecord
	degreeMorphRecord = emptyMorphRecord
end

# ╔═╡ 2d9df754-d2a3-4a68-8655-a5bc63db37a2
Base.@kwdef mutable struct EpicToken
	sentenceIndex::Union{Int64, Nothing}
	sentenceUrn::Union{Cite2Urn, Nothing}
	sentenceSpanUrn::Union{CtsUrn, Nothing} = nothing
	wordSyntaxIndex::Union{Int64, Nothing} = nothing # order in sentence
	tokenIndex::Union{Int64, Nothing} = nothing # in the whole poem
	sentenceID::String = ""
	wordID::String = ""
	tokenUrn::Union{Cite2Urn, Nothing} # Cite2Urn
	form::String = ""
	lemma::String = ""
	lexUrn::Union{Cite2Urn, Nothing} = nothing
	postag::String = ""
	morphology::Union{Morphology, Nothing} = nothing
	morphLabel::String = ""
	relation::String = ""
	relationUrn::Union{CtsUrn, Nothing} = nothing
	speakerLabel::String = ""
	speakerUrn::Union{Cite2Urn, Nothing} = nothing
	head::Union{String, Nothing}
	canonicalCitation::Union{CtsUrn, Nothing} # Book + Line, e.g. μῆνιν = "1.1"
	tokenCitation::Union{CtsUrn, Nothing} # Book + Line + Token, e.g. μῆνιν = "1.1.1"
end

# ╔═╡ 72bfb9e8-20d8-4354-bcb8-fefc1f4a0569
iliadTokenVec1 = map(collect(enumerate(iliadSents))) do (index, sent)
	# Grab the sentence-id so we can attach it to every token
	sentenceID = sent["id"]
	sentenceIndex = index
	map(collect(enumerate(findall("word", sent)))) do (index, word)
		thisToken = EpicToken(
			sentenceIndex = sentenceIndex,
			wordSyntaxIndex = index,
			sentenceUrn = Cite2Urn("urn:cite2:fuUltHomer:iliadSentences.2022a:$sentenceIndex"),
			tokenUrn = Cite2Urn("urn:cite2:fuUltHomer:iliadtokens.2022a:$(sentenceID)_$index"),
			sentenceID = sentenceID,
			wordID = word["id"],
			# This replaces the "form" for ellipsis with an… uh… ellipsis
			form = begin 
				if (word["form"] == "[0]") "[…]"
				else word["form"]
				end
			end,
			lemma = word["lemma"],
			# Ellipsis tokens do not come with postags. Sigh.
			postag = begin
				if (word["postag"] == "") "u--------"
				else word["postag"]
				end
			end,
			relation = word["relation"],
			head = word["head"],
			# Punctuation does not, by default, get a CTS-URN, for some reason. We'll fix this later.
			canonicalCitation = begin
				if (word["cite"] != "")
					CtsUrn(word["cite"])
				else
					nothing
				end
			end,
			tokenCitation = nothing
		)
		thisToken
	end
end |> Iterators.flatten |> collect 

# At the end is the invokation to turn a Vector{Vector{Something}} into a Vector{Something}

# ╔═╡ 5a5008b8-8de9-4573-a2dd-8b75b7336f13
length(iliadTokenVec1) # Sanity check

# ╔═╡ 4a61f08e-d6cf-4c39-a946-59086bdd44d4
typeof(iliadTokenVec1) # Sanity check

# ╔═╡ cba29ae7-1513-40b4-b2ce-db4cddd72f0f
iliadTokenVec2 = map(collect(enumerate(iliadTokenVec1))) do (i, t)
	newT = t
	newT.tokenIndex = i
	newT
end

# ╔═╡ 1e7cd5a9-3122-4181-a4d2-a0a4f579208f
typeof(iliadTokenVec2) # Sanity check

# ╔═╡ 851feeea-68a3-437e-8aaa-f94c5a6dee5d
iliadTokenVec3 = map(collect(enumerate(iliadTokenVec2))) do (i, t)
	if (t.canonicalCitation == nothing)
		t.canonicalCitation = iliadTokenVec2[i-1].canonicalCitation
	end
	t
end

# ╔═╡ 7898ac85-f16d-42fc-8625-cb430d1aab6d
validUrns = map(t -> t.canonicalCitation, iliadTokenVec3) |> unique

# ╔═╡ 9d66251a-4d6c-4a6a-bd77-f65091552f25
length(validUrns) # sanity check

# ╔═╡ 8b63d18e-741c-426a-ade9-82005a6a91b1
# Let's get a list of forms, their CtsUrn, and their POS-Tag

justPOS = map(iliadTokenVec3) do t
	(t.canonicalCitation, t.form, t.postag)
end

# ╔═╡ 5992c467-79f8-48fc-a33d-8eb1780fa956
# Do they all have 9 characters?

filter(justPOS) do t
	length(t[3]) != 9
end |> length == 0

# ╔═╡ f851a534-e0e7-4e95-b277-ff4d78d464ae
md"""### Serialization Functions"""

# ╔═╡ 0d74143a-90a7-4056-8c40-925793572b3c
#= morphLabel	POSUrn	POSLabel	numberUrn	numberLabel	tenseUrn	tenseLabel	moodUrn	moodLabel	voiceUrn	voiceLabel	genderUrn	genderLabel	grammaticalCaseUrn	grammaticalCaseLabel	degreeUrn	degreeLabel =#

# ╔═╡ ed6d529a-cab3-49f0-8bcc-5d775cfd30dc
begin
	
	import Base.string

	function posTag(mr::MorphRecord)
		if (mr.posTag == "")
			"-"
		else
			mr.posTag
		end
	end

	function string(mr::MorphRecord)
		if (mr.long == "")
			""
		else
			mr.long
		end
	end

	
	function string(m::Morphology)
		mvs = [string(m.pos), string(m.person), string(m.number), string(m.voice), string(m.mood), string(m.tense), string(m.gender), string(m.grammaticalCase), string(m.degreeMorphRecord)]

		noblanks = filter(mvs) do s
			length(s) > 0
		end


		join(noblanks, ", ")
		
	end

	function posTag(m::Morphology)
		mvs = [posTag(m.pos), posTag(m.person), posTag(m.number), posTag(m.voice), posTag(m.mood), posTag(m.tense), posTag(m.gender), posTag(m.grammaticalCase), posTag(m.degreeMorphRecord)]

		join(mvs)

	end
	
end

# ╔═╡ 2906bc60-230b-40e3-88a8-fb8dc75bcbb9
function tabularMorphology(m::Morphology)
	tabs = [
		string(posTag(m)),
		m.pos.urnString,
		m.pos.long,
		m.number.urnString,
		m.number.long
		
		
	]
	join(tabs, "\t")
end

# ╔═╡ e20b9349-64c6-4d57-98b9-bfdf9c468f3b
function tabularEpicToken(t::EpicToken)
	rowVals = [
		string(t.tokenUrn),
		string(t.tokenIndex),
		string(t.tokenCitation),
		t.form,
		string(t.canonicalCitation),
		string(t.sentenceUrn),
		string(t.sentenceSpanUrn),
		t.lemma,
		string(t.lexUrn),
		t.postag,
		string(t.head),
		"headUrnGoesHere",
		t.relation,
		t.relationUrn,
		t.relation,
		t.speakerLabel,
		"speakerUrnGoesHere"
	]
	morphTabs = tabularMorphology(t.morphology)
	joinedLists = vcat(rowVals, morphTabs)
	tabbed = join(joinedLists, "\t")
	tabbed
end

# ╔═╡ 4e895c5e-e67d-43f2-a194-d250f86896fb
tabularEpicToken(iliadTokenVec3[2])

# ╔═╡ 84f30403-e3b9-40de-a433-29d418892b18
md"""
## Parse POSTag
"""

# ╔═╡ 65860a30-d4d2-4d6c-acb4-ce1dee36533e
md"""
Accept a POSTag; split it; treat each of the nine parts.
"""

# ╔═╡ 40dc7937-1a1d-4551-962c-c20905a2c965
begin
function getPos(s::String)
	posDict = Dict(
		# Part of Speech
		"l" => MorphRecord("l", "art", "article", "urn:cite2:fuGreekMorph:pos.2022:article"),
		"n" => MorphRecord("n", "noun", "noun", "urn:cite2:fuGreekMorph:pos.2022:noun"),
		"a" => MorphRecord("a", "adj", "adjective", "urn:cite2:fuGreekMorph:pos.2022:adjective"),
		"p" => MorphRecord("p", "pron", "pronoun", "urn:cite2:fuGreekMorph:pos.2022:pronoun"),
		"v" => MorphRecord("v", "vb", "verb", "urn:cite2:fuGreekMorph:pos.2022:verb"),
		"d" => MorphRecord("d", "adv", "adverb", "urn:cite2:fuGreekMorph:pos.2022:adverb"),
		"r" => MorphRecord("r", "prep", "preposition", "urn:cite2:fuGreekMorph:pos.2022:preposition"),
		"c" => MorphRecord("c", "conj", "conjunction", "urn:cite2:fuGreekMorph:pos.2022:conjunction"),
		"e" => MorphRecord("e", "excl", "exclamation", "urn:cite2:fuGreekMorph:pos.2022:exclamation"),
		"i" => MorphRecord("i", "inter", "interjection", "urn:cite2:fuGreekMorph:pos.2022:interjection"),
		"u" => MorphRecord("u", "punc", "punctuation", "urn:cite2:fuGreekMorph:pos.2022:punctuation"),
		"g" => MorphRecord("g", "partic", "particle", "urn:cite2:fuGreekMorph:pos.2022:particle"),
		"m" => MorphRecord("m", "num", "number", "urn:cite2:fuGreekMorph:pos.2022:number"),
		"x" => MorphRecord("x", "irr", "irregular", "urn:cite2:fuGreekMorph:pos.2022:irregular"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getPerson(s::String)
	posDict = Dict(
		# Person
		"1" => MorphRecord("1", "1st", "1st person", "urn:cite2:fuGreekMorph:person.2022:1"),
		"2" => MorphRecord("2", "2nd", "2nd person", "urn:cite2:fuGreekMorph:person.2022:2"),
		"3" => MorphRecord("3", "3rd", "3rd person", "urn:cite2:fuGreekMorph:person.2022:3"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getNumber(s::String)
	posDict = Dict(
		# Number
		"s" => MorphRecord("s", "sing", "singular", "urn:cite2:fuGreekMorph:number.2022:singular"),
		"d" => MorphRecord("d", "dl", "dual", "urn:cite2:fuGreekMorph:number.2022:plural"),
		"p" => MorphRecord("p", "pl", "plural", "urn:cite2:fuGreekMorph:number.2022:dual"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getVoice(s::String)
	posDict = Dict(
		# Voice
		"a" => MorphRecord("a", "act", "active", "urn:cite2:fuGreekMorph:voice.2022:active"),
		"m" => MorphRecord("m", "mid", "middle", "urn:cite2:fuGreekMorph:voice.2022:middle"),
		"p" => MorphRecord("p", "pass", "passive", "urn:cite2:fuGreekMorph:voice.2022:passive"),
		"e" => MorphRecord("e", "m/p", "medio-passive", "urn:cite2:fuGreekMorph:voice.2022:mediopassive"),
		"d" => MorphRecord("d", "dep", "deponent", "urn:cite2:fuGreekMorph:voice.2022:deponent"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getMood(s::String)
	posDict = Dict(
		# Mood
		"i" => MorphRecord("i", "indic", "indicative", "urn:cite2:fuGreekMorph:mood.2022:indicative"),
		"s" => MorphRecord("s", "subj", "subjunctive", "urn:cite2:fuGreekMorph:mood.2022:subjunctive"),
		"n" => MorphRecord("n", "inf", "infinitive", "urn:cite2:fuGreekMorph:mood.2022:infinitive"),
		"m" => MorphRecord("m", "imp", "imperative", "urn:cite2:fuGreekMorph:mood.2022:imperative"),
		"p" => MorphRecord("p", "part", "participle", "urn:cite2:fuGreekMorph:mood.2022:participle"),
		"o" => MorphRecord("o", "opt", "optative", "urn:cite2:fuGreekMorph:mood.2022:optative"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getTense(s::String)
	posDict = Dict(
		# Tense
		"p" => MorphRecord("p", "pres", "present", "urn:cite2:fuGreekMorph:tense.2022:present"),
		"i" => MorphRecord("i", "imperf", "imperfect", "urn:cite2:fuGreekMorph:tense.2022:imperfect"),
		"r" => MorphRecord("r", "perf", "perfect", "urn:cite2:fuGreekMorph:tense.2022:perfect"),
		"l" => MorphRecord("l", "plupf", "pluperfect", "urn:cite2:fuGreekMorph:tense.2022:pluperfect"),
		"t" => MorphRecord("t", "futpf", "future perfect", "urn:cite2:fuGreekMorph:tense.2022:futureperfect"),
		"f" => MorphRecord("f", "fut", "future", "urn:cite2:fuGreekMorph:tense.2022:future"),
		"a" => MorphRecord("a", "aor", "aorist", "urn:cite2:fuGreekMorph:tense.2022:aorist"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getGender(s::String)
	posDict = Dict(
		# Gender
		"m" => MorphRecord("m", "masc", "masculine", "urn:cite2:fuGreekMorph:gender.2022:masculine"),
		"f" => MorphRecord("f", "fem", "feminine", "urn:cite2:fuGreekMorph:gender.2022:feminine"),
		"n" => MorphRecord("n", "neu", "neuter", "urn:cite2:fuGreekMorph:gender.2022:neuter"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getCase(s::String)
	posDict = Dict(
		# Case
		"n" => MorphRecord("n", "nom", "nominative", "urn:cite2:fuGreekMorph:case.2022:nominative"),
		"g" => MorphRecord("g", "gen", "genitive", "urn:cite2:fuGreekMorph:case.2022:genitive"),
		"d" => MorphRecord("d", "dat", "dative", "urn:cite2:fuGreekMorph:case.2022:dative"),
		"a" => MorphRecord("a", "acc", "accusative", "urn:cite2:fuGreekMorph:case.2022:accusative"),
		"v" => MorphRecord("v", "voc", "vocative", "urn:cite2:fuGreekMorph:case.2022:vocative"),
		"l" => MorphRecord("l", "loc", "locative", "urn:cite2:fuGreekMorph:case.2022:locative"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

function getDegree(s::String)
	posDict = Dict(
		# Degree
		"p" => MorphRecord("p", "pos", "positive", "urn:cite2:fuGreekMorph:degree.2022:positive"),
		"c" => MorphRecord("c", "comp", "comparative", "urn:cite2:fuGreekMorph:degree.2022:comparative"),
		"s" => MorphRecord("s", "sup", "superlative", "urn:cite2:fuGreekMorph:degree.2022:superlative"),
		"-" => emptyMorphRecord
	)

	try 
		if (s in keys(posDict)) 
			posDict[s]
		else 
			println(""" "$s" is not a valid value. The valid values are $(keys(posDict)).""")
		end
	catch e
		println(e)
	end
	
end

end


# ╔═╡ e097f26e-6453-4b10-b125-717588c92308
function getMorphology(pt::String)
	try

		ptArray = map( c -> string(c), split(pt, ""))

		
		Morphology(
			getPos(ptArray[posNum]),
			getPerson(ptArray[personNum]),
			getNumber(ptArray[numberNum]),
			getVoice(ptArray[voiceNum]),
			getMood(ptArray[moodNum]),
			getTense(ptArray[tenseNum]),
			getGender(ptArray[genderNum]),
			getCase(ptArray[caseNum]),
			getDegree(ptArray[degreeNum])
		)
		
		
			
	catch e
		println(e)
		# println(""" "$pt" must have 9 characters; it has $(length(pt)) characters.""")
	end

	
end

# ╔═╡ 234e7bbf-1078-4d86-bbf5-2fe0421b26bc
# let's try this…
map(justPOS) do p
	try 
		p[2] * ": " * string(getMorphology(p[3]))
	catch e
		println("""Bad data for: $p[1], "$p[2]", "$p[3]" """)
	end
end

# ╔═╡ 903ff1d8-3ce9-4b80-8611-048a012d0b1c
md"""A little testing."""

# ╔═╡ e802b212-d98b-425c-9132-948f3feae5fc
begin
	pt1 = "n-s---fa-" # μῆνιν
	pt2 = "v2spma---" # ἄειδε
	pt3 = "n-s---fv-" # θεὰ
	pt4 = "a-s---fa-" # οὐλομένην
	pt5 = "u--------" # ',' (comma)
	pt6 = "v3siie---" # ἐτελείετο
	pt7 = "a-s---mnc" # σαώτερος
	pt8 = "v-sappmn-" # χολωθεὶς
	pt9 = "v3saia---" # ὄρσε
	pt10 = "v-sfpmmn-" # λυσόμενός
	pt11 = "g--------" # τε
	pt12 = "p-s---mg-" # οὗ 
end

# ╔═╡ ad786f23-1e50-45e9-a6af-18b6465514e9
# "n-s---fa-" # μῆνιν
string(getMorphology(pt1))

# ╔═╡ 4a6db3bb-95bc-47ae-9513-ffaa0cc4acda
md"""### Standbox below"""

# ╔═╡ f49f23b3-bf0b-4684-bfdf-02364fe05287
testVec = ["a", "b", "c", "d", "e"]

# ╔═╡ a7b1ab22-93a4-401a-92b9-e0f492f3ca27
for (index, value) in enumerate(testVec)
   println("$index $value")
end

# ╔═╡ c84d4cc5-9723-402e-9d68-dc367be651ec
ttt = EzXML.findall("word", iliadSents[1])

# ╔═╡ 27fdb7fe-7e0e-45d9-ade5-cb21bd7bde2a
typeof(ttt)

# ╔═╡ cffc93b8-5e6c-4ac5-aa35-a7e84d2ebe0a
for sent in iliadSents
	#println(sent["id"])
	for word in findall("word", sent)
		#println(word["id"])
	end
end

# ╔═╡ e66706b8-e896-4531-a3c0-f1f50dc53af0
for word in findall("word", iliadSents[3])
	println(word["id"])
	println(word["form"])
	println(word["lemma"])
	println(word["postag"])
	println(word["relation"])
	println(word["head"])
	println(word["cite"])
	println(haskey(word, "artificial"))
	println(haskey(word, "insertion_id"))
end

# ╔═╡ 1a486e5b-390e-4850-90d4-17b9a8cd8694
xxx = "dogs"

# ╔═╡ 61037013-93d7-424c-bae2-d70ab4cd3c11
yyy = begin

	if (xxx == "dogs")
		true
	else
		false
	end
end

# ╔═╡ 5f8e605b-a0e1-46a5-bd42-f10e5f85cf52
a = ["a", "b", "c"];

# ╔═╡ 276b5060-b3c8-4791-ae2e-2e10aa2799fe
map(collect(enumerate(a))) do (i, v)
	i
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CitableBase = "d6f014bd-995c-41bd-9893-703339864534"
CitableCorpus = "cf5ac11a-93ef-4a1a-97a3-f6af101603b5"
CitableObject = "e2b2f5ea-1cd8-4ce8-9b2b-05dad64c2a57"
CitableText = "41e66566-473b-49d4-85b7-da83b66615d8"
EzXML = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
PolytonicGreek = "72b824a7-2b4a-40fa-944c-ac4f345dc63a"
SplitApplyCombine = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
Unicode = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[compat]
CitableBase = "~10.2.4"
CitableCorpus = "~0.12.6"
CitableObject = "~0.15.1"
CitableText = "~0.15.2"
EzXML = "~1.1.0"
PolytonicGreek = "~0.17.21"
SplitApplyCombine = "~1.2.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.2"
manifest_format = "2.0"
project_hash = "155225ea8aaca8cb0083c2646cf7737f06bf3e2c"

[[deps.ANSIColoredPrinters]]
git-tree-sha1 = "574baf8110975760d391c710b6341da1afa48d8c"
uuid = "a4c015fc-c6ff-483c-b24f-f7ea428134e9"
version = "0.0.1"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "84259bb6172806304b9101094a7cc4bc6f56dbc6"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.5"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "c5fd7cd27ac4aed0acf4b73948f0110ff2a854b2"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.7"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "e7ff6cadf743c098e08fca25c91103ee4303c9bb"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.6"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.CitableBase]]
deps = ["DocStringExtensions", "Documenter", "HTTP", "Test"]
git-tree-sha1 = "80afb8990f22cb3602aacce4c78f9300f67fdaae"
uuid = "d6f014bd-995c-41bd-9893-703339864534"
version = "10.2.4"

[[deps.CitableCorpus]]
deps = ["CitableBase", "CitableText", "CiteEXchange", "DocStringExtensions", "Documenter", "HTTP", "Tables", "Test"]
git-tree-sha1 = "a40fb467ba6d61e02f6aaf5c1d9147c869bfa17f"
uuid = "cf5ac11a-93ef-4a1a-97a3-f6af101603b5"
version = "0.12.6"

[[deps.CitableObject]]
deps = ["CitableBase", "CiteEXchange", "DocStringExtensions", "Documenter", "Downloads", "Test"]
git-tree-sha1 = "e147d2fa5fd4c036fd7b0ba0d14bf60d26dfefd2"
uuid = "e2b2f5ea-1cd8-4ce8-9b2b-05dad64c2a57"
version = "0.15.1"

[[deps.CitableText]]
deps = ["CitableBase", "DocStringExtensions", "Documenter", "Test"]
git-tree-sha1 = "87c096e67162faf21c0983a29396270cca168b4e"
uuid = "41e66566-473b-49d4-85b7-da83b66615d8"
version = "0.15.2"

[[deps.CiteEXchange]]
deps = ["CSV", "CitableBase", "DocStringExtensions", "Documenter", "HTTP", "Test"]
git-tree-sha1 = "8637a7520d7692d68cdebec69740d84e50da5750"
uuid = "e2e9ead3-1b6c-4e96-b95f-43e6ab899178"
version = "0.10.1"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "3ca828fe1b75fa84b021a7860bd039eaea84d2f2"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.3.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.DataAPI]]
git-tree-sha1 = "46d2680e618f8abd007bce0c3026cb0c4a8f2032"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.12.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DeepDiffs]]
git-tree-sha1 = "9824894295b62a6a4ab6adf1c7bf337b3a9ca34c"
uuid = "ab62b9b5-e342-54a8-a765-a90f495de1a6"
version = "1.2.0"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "e82c3c97b5b4ec111f3c1b55228cebc7510525a2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.25"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "c36550cb29cbe373e95b3f40486b9a4148f89ffd"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.2"

[[deps.Documenter]]
deps = ["ANSIColoredPrinters", "Base64", "Dates", "DocStringExtensions", "IOCapture", "InteractiveUtils", "JSON", "LibGit2", "Logging", "Markdown", "REPL", "Test", "Unicode"]
git-tree-sha1 = "6030186b00a38e9d0434518627426570aac2ef95"
uuid = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
version = "0.27.23"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EzXML]]
deps = ["Printf", "XML2_jll"]
git-tree-sha1 = "0fa3b52a04a4e210aeb1626def9c90df3ae65268"
uuid = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
version = "1.1.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "Dates", "IniFile", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "a97d47758e933cd5fe5ea181d178936a9fc60427"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.5.1"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "a62189e59d33e1615feb7a48c0bea7c11e4dc61d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.3.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "94d9c52ca447e23eac0c0f074effbcd38830deb5"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.18"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "5d4d2d9904227b8bd66386c1138cf4d5ffa826bf"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "0.4.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "3c3c4a401d267b04942545b1e964a20279587fd7"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.3.0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6e9dba33f9f2c44e08a020b0caf6903be540004"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.19+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Orthography]]
deps = ["CitableBase", "CitableCorpus", "CitableText", "Compat", "DocStringExtensions", "Documenter", "OrderedCollections", "StatsBase", "Test", "TestSetExtensions", "TypedTables", "Unicode"]
git-tree-sha1 = "9d643f92145f36ad2284b5cb74281df1255712af"
uuid = "0b4c9448-09b0-4e78-95ea-3eb3328be36d"
version = "0.17.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "6c01a9b494f6d2a9fc180a08b182fcb06f0958a0"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.4.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.PolytonicGreek]]
deps = ["Compat", "DocStringExtensions", "Documenter", "Orthography", "Test", "TestSetExtensions", "Unicode"]
git-tree-sha1 = "4f5836914e6927f8094d04b1c1b25167bd7d839e"
uuid = "72b824a7-2b4a-40fa-944c-ac4f345dc63a"
version = "0.17.21"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "efd23b378ea5f2db53a55ae53d3133de4e080aa9"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.16"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "48f393b0231516850e39f6c756970e7ca8b77045"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.2.2"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "c79322d36826aa2f4fd8ecfa96ddb47b174ac78d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TestSetExtensions]]
deps = ["DeepDiffs", "Distributed", "Test"]
git-tree-sha1 = "3a2919a78b04c29a1a57b05e1618e473162b15d0"
uuid = "98d24dd4-01ad-11ea-1b02-c9a08f80db04"
version = "2.0.0"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "8a75929dcd3c38611db2f8d08546decb514fcadf"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.9"

[[deps.TypedTables]]
deps = ["Adapt", "Dictionaries", "Indexing", "SplitApplyCombine", "Tables", "Unicode"]
git-tree-sha1 = "ec72e7a68a6ffdc507b751714ff3e84e09135d9e"
uuid = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"
version = "1.4.1"

[[deps.URIs]]
git-tree-sha1 = "e59ecc5a41b000fa94423a578d29290c7266fc10"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "58443b63fb7e465a8a7210828c91c08b92132dff"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.14+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═4fbd0098-5b2e-11ed-1a87-11df2c7d3e12
# ╠═631f349a-e339-4dca-94e2-19234c92c79f
# ╟─7caf2ece-3164-431c-9d4b-00a89b691271
# ╠═4d074d84-84ac-479b-b048-fe9833e06c69
# ╠═560adbd8-1316-4ae4-b1b8-72aac8ef5bfa
# ╠═ad54a5ad-3021-421b-94a7-78b62e9e4158
# ╠═a15ddf82-1141-45a7-b382-0cf0fbfe3cdb
# ╠═15cc96d6-327c-45f8-a40e-c55268eca05b
# ╟─87dbb837-a07b-4579-b1b7-59544ab61400
# ╟─3dc1b3f5-d60b-4427-841d-6c218b8c94a9
# ╠═2d9df754-d2a3-4a68-8655-a5bc63db37a2
# ╠═4e895c5e-e67d-43f2-a194-d250f86896fb
# ╟─15263e0a-3566-4e55-8352-a08b22ba7461
# ╠═e20b9349-64c6-4d57-98b9-bfdf9c468f3b
# ╟─f967e8b2-9ed9-4636-8365-7acd5337ec5b
# ╠═035ca287-1f81-44c4-9929-688a58386a74
# ╠═fcf317b0-6dd2-42c6-8713-3facf3cff9b1
# ╟─192eb118-57a4-4209-ad84-fab8b5693159
# ╟─944cc2d5-6be8-4e71-b9bf-b3a4f8e766a8
# ╠═72bfb9e8-20d8-4354-bcb8-fefc1f4a0569
# ╠═5a5008b8-8de9-4573-a2dd-8b75b7336f13
# ╠═4a61f08e-d6cf-4c39-a946-59086bdd44d4
# ╟─db78845e-9134-4a05-a2a0-ea8492027918
# ╟─858378c7-cd4c-41cd-93fc-106a6af3e432
# ╠═cba29ae7-1513-40b4-b2ce-db4cddd72f0f
# ╠═1e7cd5a9-3122-4181-a4d2-a0a4f579208f
# ╟─4b5ac42f-f211-4d45-a6ea-ce2c25c8260d
# ╠═851feeea-68a3-437e-8aaa-f94c5a6dee5d
# ╟─3679562c-964a-481f-8a5c-d873070b0b47
# ╠═7898ac85-f16d-42fc-8625-cb430d1aab6d
# ╠═9d66251a-4d6c-4a6a-bd77-f65091552f25
# ╟─2017ef58-a1b4-4429-85e3-54d5f10f0af0
# ╠═744f91eb-b548-4090-b2fb-4620bb373fcb
# ╟─857ecb3a-e195-4859-bddb-6821ae03b3fa
# ╠═8b63d18e-741c-426a-ade9-82005a6a91b1
# ╠═5992c467-79f8-48fc-a33d-8eb1780fa956
# ╠═234e7bbf-1078-4d86-bbf5-2fe0421b26bc
# ╟─867cc35d-f364-4a1b-83a2-6c9283e41250
# ╟─5079fb39-7c46-4421-95dd-88371c8ff72f
# ╠═8ead2580-0275-4ba9-a500-790ad58a72f0
# ╠═a23071ce-7184-44dd-a423-9465e4aacd7e
# ╟─e3c5b465-37e8-43ba-8aa8-870321a559df
# ╠═2af42b75-4b13-4314-85f9-1df91968bfa1
# ╠═7b0f510a-4a21-49cd-b80c-4aac003c713c
# ╟─11b3f65f-3062-4ff2-ae7a-227d14f21f07
# ╠═efe42e6d-d20f-44d6-9706-946c63f400c5
# ╟─1ac5df9c-870d-4985-b1c7-b924c59aa673
# ╠═ad6a60bb-a15f-41ee-b335-69fc46239c0d
# ╠═e11f6ef9-7624-44e5-adf4-453e685b8c07
# ╟─f851a534-e0e7-4e95-b277-ff4d78d464ae
# ╠═0d74143a-90a7-4056-8c40-925793572b3c
# ╠═2906bc60-230b-40e3-88a8-fb8dc75bcbb9
# ╠═ed6d529a-cab3-49f0-8bcc-5d775cfd30dc
# ╟─84f30403-e3b9-40de-a433-29d418892b18
# ╟─65860a30-d4d2-4d6c-acb4-ce1dee36533e
# ╠═e097f26e-6453-4b10-b125-717588c92308
# ╠═40dc7937-1a1d-4551-962c-c20905a2c965
# ╠═903ff1d8-3ce9-4b80-8611-048a012d0b1c
# ╠═e802b212-d98b-425c-9132-948f3feae5fc
# ╠═ad786f23-1e50-45e9-a6af-18b6465514e9
# ╟─4a6db3bb-95bc-47ae-9513-ffaa0cc4acda
# ╠═f49f23b3-bf0b-4684-bfdf-02364fe05287
# ╠═a7b1ab22-93a4-401a-92b9-e0f492f3ca27
# ╠═c84d4cc5-9723-402e-9d68-dc367be651ec
# ╠═27fdb7fe-7e0e-45d9-ade5-cb21bd7bde2a
# ╠═cffc93b8-5e6c-4ac5-aa35-a7e84d2ebe0a
# ╠═e66706b8-e896-4531-a3c0-f1f50dc53af0
# ╠═1a486e5b-390e-4850-90d4-17b9a8cd8694
# ╠═61037013-93d7-424c-bae2-d70ab4cd3c11
# ╠═5f8e605b-a0e1-46a5-bd42-f10e5f85cf52
# ╠═276b5060-b3c8-4791-ae2e-2e10aa2799fe
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
