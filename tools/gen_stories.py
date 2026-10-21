"""Generates assets/data/stories.json. Each page: (image number, lead, body)."""
import json, sys

STORIES = [
    ("going_to_school", "Going to School", [
        (1, "First, we get dressed and put on our backpack.", "Then we go to school with our family."),
        (2, "We ride the bus or walk to school.", "We stay close to our grown-up."),
        (3, "We say goodbye to our family.", "They will come back to pick us up."),
        (4, "We say hello to our teacher.", "Our teacher is happy to see us."),
        (2, "We find our seat in the classroom.", "We listen and learn new things."),
        (1, "At the end of the day, we go home.", "We can tell our family about our day."),
    ]),
    ("going_to_the_toilet", "Going to the Toilet", [
        (1, "First, we know we need the toilet.", "We can tell a trusted adult and go to the bathroom."),
        (2, "We pull down our pants and sit on the toilet.", "We can take our time. That is okay."),
        (2, "When we are done, we use toilet paper.", "We wipe from front to back."),
        (3, "We flush the toilet.", "It might be loud, and that is okay."),
        (3, "We pull up our pants.", "We check that our clothes are on right."),
        (3, "We wash our hands with soap and water.", "We scrub while we sing a little song."),
        (4, "We dry our hands with a towel.", "Now our hands are clean."),
        (1, "We did it!", "Going to the toilet is part of every day."),
    ]),
    ("going_to_the_doctor", "Going to the Doctor", [
        (1, "First, we go to the doctor.", "The doctor will check how we are feeling and help us stay healthy."),
        (2, "The doctor says hello.", "We can say hello back or wave."),
        (3, "The doctor listens to our heart.", "The stethoscope may feel cold. That is okay."),
        (4, "The doctor looks in our ears and mouth.", "We can open wide and say 'ahh'."),
        (2, "We can tell the doctor how we feel.", "It is okay to ask questions."),
        (1, "When we are done, we say thank you.", "Going to the doctor helps us stay well."),
    ]),
    ("brushing_teeth", "Brushing Teeth", [
        (1, "First, we get our toothbrush.", "Then we put toothpaste on it and brush our teeth."),
        (2, "We squeeze a little toothpaste.", "A tiny bit, like a pea, is just right."),
        (3, "We brush our front teeth and back teeth.", "Round and round, up and down."),
        (4, "We brush for two minutes.", "We can count or sing a song."),
        (2, "We spit out the toothpaste.", "Then we rinse our toothbrush."),
        (3, "Our teeth are clean and shiny!", "We brush in the morning and at night."),
    ]),
    ("restaurant", "Restaurant", [
        (1, "First, we sit at the table.", "Then we choose what we want and tell the person."),
        (2, "We look at the menu.", "We can point to pictures of food we like."),
        (3, "We wait for our food.", "Waiting can be hard. We can draw or talk quietly."),
        (4, "We eat our food with our family.", "We use our inside voice."),
        (2, "We say please and thank you.", "Good manners are kind."),
        (1, "When we are finished, we go home.", "Eating out can be fun."),
    ]),
    ("airport", "Airport", [
        (1, "First, we arrive at the airport.", "Then we check in and go through security."),
        (2, "We show our tickets and give our big bags.", "Our bags will meet us later."),
        (3, "We go through security.", "We put our things in a tray. The staff help keep us safe."),
        (1, "We wait at the gate.", "We can look at the planes through the window."),
        (2, "We get on the plane and find our seat.", "We buckle our seatbelt."),
        (1, "The plane goes up into the sky.", "Our ears may feel funny. We can swallow or yawn."),
        (4, "We land and ride to where we are going.", "We made it to our trip!"),
    ]),
    ("playground", "Playground", [
        (1, "First, we wait for our turn.", "Then we can play together and be kind."),
        (2, "We go down the slide one at a time.", "We wait until the slide is clear."),
        (3, "We can ask a friend to play.", "We can say, 'Do you want to play with me?'"),
        (4, "We take turns on the swings.", "Everyone gets a turn."),
        (3, "If someone gets hurt, we can help.", "We can find a trusted adult."),
        (1, "When it is time to go, we say goodbye.", "We can come back another day."),
    ]),
    ("sharing", "Sharing", [
        (1, "Sharing is kind.", "We can take turns and share our toys with friends."),
        (2, "We can ask, 'Can I have a turn?'", "Then we wait for our friend to answer."),
        (3, "We can give a toy to a friend.", "Our friend feels happy."),
        (4, "Sharing makes playing more fun.", "We can play together."),
        (2, "Sometimes we have to wait.", "We can play with something else while we wait."),
        (1, "We feel proud when we share.", "Sharing is being a good friend."),
    ]),
    ("asking_for_help", "Asking for Help", [
        (1, "If we need help, we can ask a trusted adult.", "It is okay to ask for help."),
        (2, "Trusted adults are people like our family and teachers.", "They want to help us."),
        (3, "We can raise our hand or say, 'Help, please.'", "We use a calm voice."),
        (4, "We tell them what we need.", "We can use words, pictures, or point."),
        (2, "The adult listens and helps us.", "We say thank you."),
        (1, "Asking for help is brave.", "Everyone needs help sometimes."),
    ]),
    ("personal_space", "Personal Space", [
        (1, "We give people space.", "We do not stand too close to others."),
        (2, "An arm's length is a good space.", "We can stretch out our arm to check."),
        (3, "We ask before we hug.", "We can say, 'Can I have a hug?'"),
        (4, "If someone says no, that is okay.", "We can wave or give a high five instead."),
        (2, "Other people give us space too.", "We can say, 'Please give me some space.'"),
        (1, "Giving space helps everyone feel comfortable.", "Space is a way to be kind."),
    ]),
    ("saying_no", "Saying No", [
        (1, "It is okay to say 'No, thank you.'", "We can say no if we don't want something."),
        (2, "We can use a kind voice.", "We can shake our head or say, 'No, thank you.'"),
        (3, "Other people can say no to us too.", "We listen and say okay."),
        (4, "If we feel unsafe, we can say 'No!' loudly.", "Then we tell a trusted adult."),
        (2, "Our body belongs to us.", "We can say no to touches we do not want."),
        (1, "Saying no is okay.", "We can be kind and still say no."),
    ]),
    ("staying_safe", "Staying Safe", [
        (1, "We stay with our trusted adults.", "We follow safety rules like looking both ways before we cross."),
        (2, "We hold hands near busy roads.", "We stay on the sidewalk."),
        (3, "We wait for the green light.", "Green means walk. Red means stop."),
        (4, "If we get lost, we stay where we are.", "We can ask a helper, like a police officer or a shop worker."),
        (2, "We know our grown-up's name.", "This helps people find them."),
        (1, "Staying safe keeps us happy and healthy.", "We can always ask for help."),
    ]),
]


FOCUS = {
  "going_to_school": {"kid": (-0.35,-0.1,1.45), "adult": (0.35,-0.6,1.45), "bag": (-0.5,0.5,1.35), "wide": (0,0,1.15)},
  "going_to_the_toilet": {"kid": (-0.15,-0.25,1.45), "sign": (0.45,-0.7,1.45), "door": (0.6,0.1,1.4), "sink": (-0.8,0.2,1.4), "wide": (0,0,1.15)},
  "going_to_the_doctor": {"kid": (-0.35,-0.1,1.45), "adult": (0.5,-0.5,1.45), "hands": (0.3,0.5,1.4), "wide": (0,0,1.15)},
  "brushing_teeth": {"kid": (-0.05,-0.45,1.45), "brush": (0.4,0.0,1.45), "duck": (0.85,0.3,1.4), "wide": (0,0,1.15)},
  "restaurant": {"kid": (-0.5,-0.1,1.45), "adult": (0.6,-0.3,1.45), "menu": (0.0,0.6,1.4), "wide": (0,0,1.15)},
  "airport": {"kid": (-0.3,0.3,1.45), "plane": (0.5,0.1,1.45), "sign": (0.0,-0.8,1.4), "wide": (0,0,1.15)},
  "playground": {"kid": (-0.45,-0.2,1.45), "friend": (0.45,0.0,1.45), "slide": (-0.1,-0.6,1.4), "wide": (0,0,1.15)},
  "sharing": {"kid": (-0.4,-0.1,1.45), "friend": (0.6,-0.1,1.45), "toy": (0.1,0.4,1.45), "wide": (0,0,1.15)},
  "asking_for_help": {"kid": (-0.5,0.1,1.45), "adult": (1.0,-0.4,1.3), "bubble": (0.85,-0.4,1.4), "wide": (0.6,-0.6,1.15)},
  "personal_space": {"kid": (-0.6,-0.1,1.45), "friend": (0.6,0.0,1.45), "arrow": (0.0,0.0,1.35), "wide": (0,0,1.15)},
  "saying_no": {"kid": (-0.8,0.4,1.15), "bubble": (0.0,-1.0,1.4), "candy": (0.8,-1.0,1.3), "wide": (0,-1.0,1.12)},
  "staying_safe": {"kid": (-0.1,0.1,1.45), "adult": (0.6,-0.4,1.45), "light": (-0.3,-0.7,1.45), "road": (0.0,0.8,1.35), "wide": (0,0,1.15)},
}
# which focus each page uses (page 1 is always the full picture)
SHOTS = {
  "going_to_school": [None,"wide","adult","kid","bag",None],
  "going_to_the_toilet": [None,"kid","wide","door","kid","sink","sink",None],
  "going_to_the_doctor": [None,"adult","hands","adult","kid",None],
  "brushing_teeth": [None,"brush","kid","wide","duck",None],
  "restaurant": [None,"menu","kid","wide","adult",None],
  "airport": [None,"kid","wide","plane","kid","plane",None],
  "playground": [None,"slide","kid","friend","wide",None],
  "sharing": [None,"kid","toy","friend","wide",None],
  "asking_for_help": [None,"adult","bubble","kid","wide",None],
  "personal_space": [None,"arrow","kid","friend","wide",None],
  "saying_no": [None,"bubble","candy","kid","wide",None],
  "staying_safe": [None,"road","light","kid","adult",None],
}

img = lambda sid, n=None: f"assets/images/stories/{sid}.png"
def page(sid, i, lead, body):
    shots = SHOTS[sid]
    assert len(shots) == len(STORIES_BY_ID[sid]), sid
    d = {"image": img(sid), "lead": lead, "body": body}
    if shots[i]:
        x, y, z = FOCUS[sid][shots[i]]
        d["focus"] = {"x": x, "y": y, "zoom": z}
    return d

STORIES_BY_ID = {sid: pages for sid, _t, pages in STORIES}
data = {"version": 1, "stories": [
    {"id": sid, "title": title,
     "pages": [page(sid, i, lead, body) for i, (_n, lead, body) in enumerate(pages)]}
    for sid, title, pages in STORIES]}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
