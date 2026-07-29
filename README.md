# TrackMaxx
I have found that a lot of calorie trackers in the market look similar and have the same features so I built a conversational iOS calorie tracker, you talk to an AI nutrition agent instead of filling out forms, and it logs your meals without much hassle. 

#Features
One thread per day — a real conversation with an agent that logs, edits, and answers questions about what you've eaten.
Snap a photo of your plate and the agent identifies it.
Every food gets a consistent, studio-quality generated photo.
Pinch-to-zoom between the day's conversation and a full photo timeline.
Custom liquid-glass design with Metal-shader transitions throughout.
Offline nutrition database with ~150 common foods, plus the agent's own knowledge for anything else.

#Tech Stack
For UI, I used swiftUI libraries as it aligns the most with Apple's own libraries and interfaces.
For databases and data storage, I used SwiftData for data storage and an offline JSON file to hold the actual database that holds pre-loaded values of meals and related information.
Since this app is made for iOS models, most of the coding has taken place on XCode which allows the testing to occur directly on iOS systems.

