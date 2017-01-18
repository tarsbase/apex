defmodule Ello.V2.UserViewTest do
  use Ello.V2.ConnCase, async: true
  import Phoenix.View #For render/2
  alias Ello.V2.UserView

  setup %{conn: conn} do
    archer = Script.build(:archer)
    user = Factory.build(:user, %{
      id: 1234,
      relationship_to_current_user: Factory.build(:relationship,
                                                  owner: archer,
                                                  priority: "friend")
    })
    {:ok, conn: user_conn(conn, archer), archer: archer, user: user}
  end

  test "user.json - it renders the user", %{conn: conn, archer: archer} do
    expected = %{
      id: "42",
      href: "/api/v2/users/42",
      username: "archer",
      name: "Sterling Archer",
      location: "New York, NY",
      posts_adult_content: false,
      views_adult_content: true,
      has_commenting_enabled: true,
      has_sharing_enabled: true,
      has_reposting_enabled: true,
      has_loves_enabled: true,
      has_auto_watch_enabled: true,
      experimental_features: true,
      relationship_priority: "self",
      bad_for_seo: false,
      is_hireable: false,
      is_collaborateable: false,
      posts_count: nil,
      followers_count: nil,
      following_count: nil,
      loves_count: nil,
      #formatted_short_bio: "<p>Backend Lead <a href='/ello' class='user-mention'>@ello</a>, but fond of cars and inspired by architecture. Finding beauty in engineering.</p>",
      external_links_list: [
        %{
          url: "http://twitter.com/ArcherFX",
          text: "twitter.com/ArcherFX",
          type: "Twitter",
          icon: "https://social-icons.ello.co/twitter.png"
        },
      ],
      background_position: "50% 50%",
      avatar: %{
        "original" => %{
          "url" => "https://assets.ello.co/uploads/user/avatar/42/ello-2274bdfe-57d8-4499-ba67-a7c003d5a962.png"
        },
        "large" => %{
          "url" => "https://assets.ello.co/uploads/user/avatar/42/ello-large-fad52e18.png",
          "metadata" => %{
            "size" => 220_669,
            "type" => "image/png",
            "width" => 360,
            "height" => 360
          }
        },
        "regular" => %{
          "url" => "https://assets.ello.co/uploads/user/avatar/42/ello-regular-fad52e18.png",
          "metadata" => %{
            "size" => 36_629,
            "type" => "image/png",
            "width" => 120,
            "height" => 120
          }
        },
        "small" => %{
          "url" => "https://assets.ello.co/uploads/user/avatar/42/ello-small-fad52e18.png",
          "metadata" => %{
            "size" => 17_753,
            "type" => "image/png",
            "width" => 60,
            "height" => 60
          }
        }
      },
      cover_image: %{
        "original" => %{
          "url" => "https://assets.ello.co/uploads/user/cover_image/42/ello-e76606cf-44b0-48b5-9918-1efad8e0272c.jpeg"
        },
        "optimized" => %{
          "url" => "https://assets.ello.co/uploads/user/cover_image/42/ello-optimized-061fb4e4.jpg",
          "metadata" => %{
            "size" => 1_177_127,
            "type" => "image/jpeg",
            "width" => 1880,
            "height" => 1410
          }
        },
        "xhdpi" => %{
          "url" => "https://assets.ello.co/uploads/user/cover_image/42/ello-xhdpi-061fb4e4.jpg",
          "metadata" => %{
            "size" => 582_569,
            "type" => "image/jpeg",
            "width" => 1116,
            "height" => 837
          }
        },
        "hdpi" => %{
          "url" => "https://assets.ello.co/uploads/user/cover_image/42/ello-hdpi-061fb4e4.jpg",
          "metadata" => %{
            "size" => 150_067,
            "type" => "image/jpeg",
            "width" => 552,
            "height" => 414
          }
        },
        "mdpi" => %{
          "url" => "https://assets.ello.co/uploads/user/cover_image/42/ello-mdpi-061fb4e4.jpg",
          "metadata" => %{
            "size" => 40_106,
            "type" => "image/jpeg",
            "width" => 276,
            "height" => 207
          }
        },
        "ldpi" => %{
          "url" => "https://assets.ello.co/uploads/user/cover_image/42/ello-ldpi-061fb4e4.jpg",
          "metadata" => %{
            "size" => 10_872,
            "type" => "image/jpeg",
            "width" => 132,
            "height" => 99
          }
        }
      },
      links: %{categories: []}
    }
    assert render(UserView, "user.json", user: archer, conn: conn) == expected
  end

  test "user.json - knows user relationship", %{conn: conn, user: user} do
    assert render(UserView, "user.json", user: user, conn: conn).relationship_priority == "friend"
  end
end
