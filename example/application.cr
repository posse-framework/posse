require "log"
require "uuid"

require "../src/posse"

require "./**"

Log.setup(:debug)

id = UUID.random.to_s

register_command = Example::Commands::RegisterUser.new(
  id: id,
  first_name: "John",
  last_name: "Doe",
  email: "john@doe.com",
  password: "Abcd1234!@#$"
)

# TODO: Add actual strong and eventual consistencies
result = Example::Router.dispatch(register_command, consistency: Posse::Commands::Consistency::Strong)

update_command = Example::Commands::ChangeUserFirstName.new(
  id: id,
  first_name: "James"
)

loop do
  result = Example::Router.dispatch(update_command, consistency: Posse::Commands::Consistency::Strong)
  sleep 0.1
end

store = Example::Projectors::User.store.as(Posse::Projectors::Stores::InMemory)

pp store
