defmodule Codebattle.Bot.GameCreator do
  alias Codebattle.GameProcess.Play
  alias Codebattle.Repo
  alias Codebattle.Bot.{Playbook, SocketDriver}

  import Ecto.Query, warn: false

  @spec call() ::
          {:ok, game_id :: integer}
          | {:error, :enough_games}
          | {:error, :no_playbooks}
  def call() do
    # TODO: think about more smart solution
    query =
      from(
        playbook in Playbook,
        where: [lang: "ruby"],
        preload: [:task]
      )

    with true <- game_shortage?,
         playbook when not is_nil(playbook) <- Repo.one(query) do
      bot = Codebattle.Bot.Builder.build(%{lang: "ruby"})

      {:ok, socket_pid} =
        SocketDriver.start_link(CodebattleWeb.Endpoint, CodebattleWeb.UserSocket)

      {:ok, game_id} = Play.create_bot_game(bot, playbook.task)

      # TODO: add socket with bot to game process
      game_topic = "game:#{game_id}"
      SocketDriver.join(socket_pid, game_topic)

      {:ok, game_id}
    else
      false -> {:error, :enough_games}
      nil -> {:error, :no_playbooks}
    end
  end

  defp game_shortage? do
    3 > length(Play.list_games())
  end
end
