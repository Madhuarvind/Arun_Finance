from app import create_app
from models import Collection

app = create_app()
with app.app_context():
    c = Collection.query.get(7)
    if c:
        print(f"Collection 7 Agent ID: {c.agent_id}")
        if c.agent:
            print(f"Agent Name: {c.agent.name}")
        else:
            print("Agent relationship is NONE")
    else:
        print("Collection 7 not found")
