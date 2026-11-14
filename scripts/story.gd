extends RefCounted

# Story text shown before each level (and after beating Level 4).

const INTRO := {
	1: {
		"place": "A village wedding",
		"pages": [
			"Our kompang band had no fans, no bookings, and one very old drum.",
			"Then we heard the news: our rival had been booked for the wedding of the year, and they were too busy bragging to confirm it.",
			"So we turned up first. The family never knew the difference.\n\nTonight, we steal the job. Do not mess it up.",
		],
	},
	2: {
		"place": "The wedding circuit",
		"pages": [
			"The guests filmed everything. By morning, the whole town was talking about us.",
			"We were famous. Bookings poured in: long processions, endless drum rolls, weddings every weekend.",
			"Fame is great, but the crowds demand more. Keep up the rhythm.",
		],
	},
	3: {
		"place": "The biggest wedding yet",
		"pages": [
			"Our biggest gig ever. Hundreds of guests, and the whole band in full swing.",
			"Then the music stopped. The bride was gone, kidnapped in the middle of the ceremony!",
			"Whoever took her left traps along the route. Bombs, hidden in the beat.\n\nDo NOT touch them.",
		],
	},
	4: {
		"place": "The port at midnight",
		"pages": [
			"The clues all point to the port: cranes, crates, and a foghorn in the dark.",
			"And waiting on the dock, drums in hand, is our rival. They took the bride to get revenge for the stolen gig.",
			"They challenge us to a battle of kompang. If we lose, we hang. If we win, they do.

Bring her home.",
		],
	},
}

const ENDINGS := {
	"good": {
		"place": "Dawn at the port",
		"pages": [
			"The last beat rang out over the water. Our rival's drum fell silent, and the bride was safe.",
			"The harbour guards had heard everything. The rival was tried for the kidnapping, and at dawn they were hanged.",
			"The wedding went ahead at sunrise with our band playing. From the stolen gig to the port, we became a legend.",
		],
	},
	"bad": {
		"place": "Dawn at the port",
		"pages": [
			"Our rhythm broke, and our rival's drums rolled over ours. We had lost the battle.",
			"The rival kept their word. At dawn, we were hanged on the dock.",
			"The bride was never found, and the town never heard our drums again.

THE END.",
		],
	},
}
