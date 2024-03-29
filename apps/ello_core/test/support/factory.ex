defmodule Ello.Core.Factory do
  alias Ello.Core.{Repo, Discovery, Network, Content, Contest}
  alias Discovery.{Category, Promotional, Editorial, PagePromotional, CategoryPost}
  alias Network.{User, Relationship, Flag, CategoryUser}
  alias Content.{Post, Love, Watch, Asset}
  alias Contest.{ArtistInvite, ArtistInviteSubmission}
  use ExMachina.Ecto, repo: Repo

  def user_factory do
    %User{
      username:   sequence(:username, &"username#{&1}"),
      email:      sequence(:user_email, &"user-#{&1}@example.com"),
      email_hash: sequence(:user_email_hash, &"emailhash#{&1}"),
      settings:   %User.Settings{},

      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
    |> Repo.preload(:categories)
    |> User.load_images
  end

  def settings_factory do
    %User.Settings{}
  end

  def flag_factory do
    %Flag{
      reporting_user: insert(:user, is_staff: true),
      subject_user: insert(:user),
      verified: true,
      kind: "spam",
      resolved_at: DateTime.utc_now,
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
  end

  def post_factory do
    %Post{
      author:    build(:user),
      token:     sequence(:post_token, &"testtoken#{&1}wouldberandom"),
      seo_title: "test post",
      is_adult_content: false,
      is_disabled: false,
      has_nudity: false,
      is_saleable: false,
      loves_count: 1,
      comments_count: 2,
      reposts_count: 3,
      views_count: 4_123,
      body: [%{"kind" => "text", "data" => "Phrasing!"}],
      rendered_content: [%{
                           "kind" => "text",
                           "data" => "<p>Phrasing!</p>",
                           "link_url" => nil
                         }],
      rendered_summary: [%{
                           "kind" => "text",
                           "data" => "<p>Phrasing!</p>",
                           "link_url" => nil
                         }],
      reposted_source: nil,
      parent_post:     nil,
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
  end

  @doc "add 2 assets to a post"
  def add_assets(%Post{} = post) do
    add_assets(post, [insert(:asset, post: post), insert(:asset, post: post)])
  end

  @doc "add given assets to a post"
  def add_assets(%Post{body: body, rendered_content: rendered} = post, assets) do
    new_bodies = Enum.map assets, fn(%{id: id}) ->
      %{"kind" => "image", "data" => %{asset_id: id, url: "skipped"}}
    end

    new_content = Enum.map assets, fn(%{id: id}) ->
      %{"kind" => "image", "data" => %{url: "www.asdf.com", alt: "asdf"}, "links" => %{"assets" => "#{id}"}}
    end

    post
    |> Ecto.Changeset.change(body: new_bodies ++ body)
    |> Ecto.Changeset.change(rendered_content: new_content ++ rendered)
    |> Ecto.Changeset.change(rendered_summary: new_content ++ rendered)
    |> Repo.update!
    |> Repo.preload(:assets)
  end

  def repost_factory do
    post_factory()
    |> Map.merge(%{
      reposted_source: build(:post)
    })
  end

  def asset_factory do
    %Asset{
      user: build(:user),
      post: build(:post),
      attachment: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      attachment_metadata: %{
        "optimized" => %{"size"=>433_286, "type"=>"image/jpeg", "width"=>1_280, "height"=>1_024},
        "xhdpi" => %{"size"=>434_916, "type"=>"image/jpeg", "width"=>1_280, "height"=>1_024},
        "hdpi" => %{"size"=>287_932, "type"=>"image/jpeg", "width"=>750, "height"=>600},
        "mdpi" => %{"size"=>77_422, "type"=>"image/jpeg", "width"=>375, "height"=>300},
        "ldpi" => %{"size"=>19_718, "type"=>"image/jpeg", "width"=>180, "height"=>144}
      },
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    } |> Asset.build_attachment
  end

  def gif_asset_factory do
    %Asset{
      user: build(:user),
      post: build(:post),
      attachment: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.gif",
      attachment_metadata: %{
        "optimized" => %{"size"=>433_286, "type"=>"image/gif", "width"=>1_280, "height"=>1_024},
        "xhdpi" => %{"size"=>434_916, "type"=>"image/jpeg", "width"=>1_280, "height"=>1_024},
        "hdpi" => %{"size"=>287_932, "type"=>"image/jpeg", "width"=>750, "height"=>600},
        "mdpi" => %{"size"=>77_422, "type"=>"image/jpeg", "width"=>375, "height"=>300},
        "ldpi" => %{"size"=>19_718, "type"=>"image/jpeg", "width"=>180, "height"=>144}
      },
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    } |> Asset.build_attachment
  end

  def category_post_factory do
    %CategoryPost{
      status: "submitted",
      category: build(:category),
      post: build(:post),
      submitted_at: DateTime.utc_now,
    }
  end

  def category_user_factory do
    %CategoryUser{
      role: "featured",
      user: build(:user),
      category: build(:category),
    }
  end

  def featured_category_post_factory do
    %CategoryPost{
      status: "featured",
      category: build(:category),
      post: build(:post),
      submitted_at: DateTime.utc_now,
      featured_at: DateTime.utc_now,
    }
  end

  def editorial_factory do
    %Editorial{
      one_by_one_image: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      one_by_two_image: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      two_by_one_image: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      two_by_two_image: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      one_by_one_image_metadata: %{
        "optimized" => %{"size" => 555_555, "type" => "image/jpeg", "width" => 1920, "height" => 1920},
        "xhdpi" => %{"size" => 444_444, "type" => "image/jpeg", "width" => 1500, "height" => 1500},
        "hdpi" => %{"size" => 333_333, "type" => "image/jpeg", "width" => 750, "height" => 750},
        "mdpi" => %{"size" => 222_222, "type" => "image/jpeg", "width" => 375, "height" => 375},
        "ldpi" => %{"size" => 111_111, "type" => "image/jpeg", "width" => 190, "height" => 190},
      },
      one_by_two_image_metadata: %{
        "optimized" => %{"size" => 555_555, "type" => "image/jpeg", "width" => 1920, "height" => 3840},
        "xhdpi" => %{"size" => 444_444, "type" => "image/jpeg", "width" => 1500, "height" => 3000},
        "hdpi" => %{"size" => 333_333, "type" => "image/jpeg", "width" => 750, "height" => 1500},
        "mdpi" => %{"size" => 222_222, "type" => "image/jpeg", "width" => 375, "height" => 750},
        "ldpi" => %{"size" => 111_111, "type" => "image/jpeg", "width" => 190, "height" => 380},
      },
      two_by_one_image_metadata: %{
        "optimized" => %{"size" => 555_555, "type" => "image/jpeg", "width" => 1920, "height" => 960},
        "xhdpi" => %{"size" => 444_444, "type" => "image/jpeg", "width" => 1500, "height" => 750},
        "hdpi" => %{"size" => 333_333, "type" => "image/jpeg", "width" => 750, "height" => 375},
        "mdpi" => %{"size" => 222_222, "type" => "image/jpeg", "width" => 375, "height" => 188},
        "ldpi" => %{"size" => 111_111, "type" => "image/jpeg", "width" => 190, "height" => 95},
      },
      two_by_two_image_metadata: %{
        "optimized" => %{"size" => 555_555, "type" => "image/jpeg", "width" => 1920, "height" => 1920},
        "xhdpi" => %{"size" => 444_444, "type" => "image/jpeg", "width" => 1500, "height" => 1500},
        "hdpi" => %{"size" => 333_333, "type" => "image/jpeg", "width" => 750, "height" => 750},
        "mdpi" => %{"size" => 222_222, "type" => "image/jpeg", "width" => 375, "height" => 375},
        "ldpi" => %{"size" => 111_111, "type" => "image/jpeg", "width" => 190, "height" => 190},
      },
    }
  end

  def post_editorial_factory do
    Map.merge(editorial_factory(), %{
      post: build(:post),
      kind: "post",
      content: %{
        "title"              => "Post Editorial",
        "subtitle"           => "check *it* out",
        "plaintext_subtitle" => "check it out",
        "rendered_subtitle"  => "<p>check <em>it</em> out</p>",
      }
    })
  end

  def external_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "external",
      content: %{
        "title"              => "External Editorial",
        "subtitle"           => "check *it* out",
        "plaintext_subtitle" => "check it out",
        "rendered_subtitle"  => "<p>check <em>it</em> out</p>",
        "url"                => "https://ello.co/wtf",
      }
    })
  end

  def sponsored_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "sponsored",
      content: %{
        "title"              => "Sponsored Editorial",
        "subtitle"           => "check *it* out",
        "plaintext_subtitle" => "check it out",
        "rendered_subtitle"  => "<p>check <em>it</em> out</p>",
        "url"                => "https://ello.co/wtf",
      }
    })
  end

  def internal_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "internal",
      content: %{
        "title"              => "Internal Editorial",
        "subtitle"           => "check *it* out",
        "plaintext_subtitle" => "check it out",
        "rendered_subtitle"  => "<p>check <em>it</em> out</p>",
        "path"               => "/discover/recent",
      }
    })
  end

  def category_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "category",
      content: %{
        "title" => "Category Editorial",
        "slug"  => "shop",
      }
    })
  end

  def artist_invite_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "artist_invite",
      content: %{
        "title" => "Artist Invite Editorial",
        "slug"  => "nfp-100",
      }
    })
  end

  def curated_posts_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "curated_posts",
      content: %{
        "title"       => "Curated Posts Editorial",
        "post_tokens" => [insert(:post).token, insert(:post).token]
      }
    })
  end

  def following_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "following",
      content: %{
        "title" => "Following Editorial",
      }
    })
  end

  def invite_join_editorial_factory do
    Map.merge(editorial_factory(), %{
      kind: "invite_join",
      content: %{
        "title" => "Join or Invite Editorial",
      }
    })
  end

  def love_factory do
    %Love{
      user: build(:user),
      post: build(:post),
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
  end

  def watch_factory do
    %Watch{
      user: build(:user),
      post: build(:post),
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
  end

  def comment_factory do
    post_factory()
    |> Map.merge(%{
      parent_post: build(:post)
    })
  end

  def category_factory do
    %Category{
      name:        sequence(:category_name, &"category#{&1}"),
      slug:        sequence(:category_slug, &"category#{&1}"),
      roshi_slug:  sequence(:category_roshi_slug, &"category#{&1}"),
      description: "Posts about this categories",
      is_sponsored: false,
      is_creator_type: false,
      level:       "Primary",
      order:        Enum.random(0..10),
      uses_page_promotionals: false,
      promotionals: [build(:promotional)],
      created_at:   DateTime.utc_now,
      updated_at:   DateTime.utc_now,
    } |> Category.load_images
  end

  def promotional_factory do
    %Promotional{
      image: "ello-optimized-da955f87.jpg",
      image_metadata: %{},
      post_token: "abc-123",
      user: build(:user),
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    } |> Promotional.load_images
  end

  def page_promotional_factory do
    %PagePromotional{
      header: "Header",
      subheader: "Sub Header",
      cta_href: nil,
      cta_caption: nil,
      is_logged_in: false,
      is_editorial: false,
      is_artist_invite: false,
      is_authentication: false,
      image: "ello-optimized-da955f87.jpg",
      image_metadata: %{},
      post_token: "abc-123",
      user: build(:user),
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    } |> PagePromotional.load_images
  end

  def relationship_factory do
    %Relationship{
      priority: "friend",
      owner:    build(:user),
      subject:  build(:user),
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
  end

  def artist_invite_factory do
    %ArtistInvite{
      title: "Foo Brand",
      meta_title: "Foo Brand Art Exhibition Contest",
      invite_type: "Art Exhibition",
      slug: sequence(:slug, &"foo-brand-#{&1}"),
      brand_account: build(:user),
      opened_at: DateTime.utc_now,
      closed_at: DateTime.utc_now,
      status: "open",
      raw_description: "Foo brand is looking for artists",
      rendered_description: "<p>Foo brand is looking for artists</p>",
      meta_description: "Foo brand wants to pay you to exhibit your art. Enter to win.",
      raw_short_description: "Bar",
      rendered_short_description: "<p>Bar</p>",
      submission_body_block: "#FooBrand @FooBrand",
      guide: [%{title: "How To Submit", raw_body: "To submit...", rendered_body: "<p>To submit...</p>"}],
      header_image: "ello-e76606cf-44b0-48b5-9918-1efad8e0272c.jpeg",
      header_image_metadata: %{
        "optimized" => %{
          "size" => 1_177_127,
          "type" => "image/jpeg",
          "width" => 1_880,
          "height" => 1_410
        },
        "xhdpi" => %{
          "size" => 582_569,
          "type" => "image/jpeg",
          "width" => 1_116,
          "height" => 837
        },
        "hdpi" => %{
          "size" => 150_067,
          "type" => "image/jpeg",
          "width" => 552,
          "height" => 414
        },
        "mdpi" => %{
          "size" => 40_106,
          "type" => "image/jpeg",
          "width" => 276,
          "height" => 207
        },
        "ldpi" => %{
          "size" => 10_872,
          "type" => "image/jpeg",
          "width" => 132,
          "height" => 99
        }
      },
      logo_image: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      logo_image_metadata: %{
        "optimized" => %{"size" => 555_555, "type" => "image/jpeg", "width" => 1920, "height" => 1920},
        "xhdpi" => %{"size" => 444_444, "type" => "image/jpeg", "width" => 1500, "height" => 1500},
        "hdpi" => %{"size" => 333_333, "type" => "image/jpeg", "width" => 750, "height" => 750},
        "mdpi" => %{"size" => 222_222, "type" => "image/jpeg", "width" => 375, "height" => 375},
        "ldpi" => %{"size" => 111_111, "type" => "image/jpeg", "width" => 190, "height" => 190},
      },
      og_image: "ello-a9c0ede1-aeca-45af-9723-5750babf541e.jpeg",
      og_image_metadata: %{
        "optimized" => %{"size" => 555_555, "type" => "image/jpeg", "width" => 1920, "height" => 1920},
        "xhdpi" => %{"size" => 444_444, "type" => "image/jpeg", "width" => 1500, "height" => 1500},
        "hdpi" => %{"size" => 333_333, "type" => "image/jpeg", "width" => 750, "height" => 750},
        "mdpi" => %{"size" => 222_222, "type" => "image/jpeg", "width" => 375, "height" => 375},
        "ldpi" => %{"size" => 111_111, "type" => "image/jpeg", "width" => 190, "height" => 190},
      },
      created_at: DateTime.utc_now,
      updated_at: DateTime.utc_now,
    }
  end

  def artist_invite_submission_factory do
    %ArtistInviteSubmission{
      artist_invite: build(:artist_invite),
      post:          build(:post),
      status:        "unapproved",
      created_at:    DateTime.utc_now,
      updated_at:    DateTime.utc_now,
    }
  end

  defmodule Script do
    use ExMachina.Ecto, repo: Repo

    def archer_factory do
      %User{
        id: 42,
        username: "archer",
        name: "Sterling Archer",
        email: "archer@ello.co",
        email_hash: "archerelloco",
        bad_for_seo?: false,
        location: "New York, NY",
        short_bio: "I have been spying for a while now",
        formatted_short_bio: "<p>I have been spying for a while now</p>",
        links: "http://www.twitter.com/ArcherFX",
        rendered_links: [
          %{"url"=>"http://www.twitter.com/ArcherFX",
            "text"=>"twitter.com/ArcherFX",
            "type"=>"Twitter",
            "icon"=>"https://social-icons.ello.co/twitter.png"},
        ],
        avatar: "ello-2274bdfe-57d8-4499-ba67-a7c003d5a962.png",
        created_at: DateTime.utc_now,
        updated_at: DateTime.utc_now,
        avatar_metadata: %{
          "large" => %{
            "size" => 220_669,
            "type" => "image/png",
            "width" => 360,
            "height" => 360
          },
          "regular" => %{
            "size" => 36_629,
            "type" => "image/png",
            "width" => 120,
            "height" => 120
          },
          "small" => %{
            "size" => 17_753,
            "type" => "image/png",
            "width" => 60,
            "height" => 60
          }
        },
        cover_image: "ello-e76606cf-44b0-48b5-9918-1efad8e0272c.jpeg",
        cover_image_metadata: %{
          "optimized" => %{
            "size" => 1_177_127,
            "type" => "image/jpeg",
            "width" => 1_880,
            "height" => 1_410
          },
          "xhdpi" => %{
            "size" => 582_569,
            "type" => "image/jpeg",
            "width" => 1_116,
            "height" => 837
          },
          "hdpi" => %{
            "size" => 150_067,
            "type" => "image/jpeg",
            "width" => 552,
            "height" => 414
          },
          "mdpi" => %{
            "size" => 40_106,
            "type" => "image/jpeg",
            "width" => 276,
            "height" => 207
          },
          "ldpi" => %{
            "size" => 10_872,
            "type" => "image/jpeg",
            "width" => 132,
            "height" => 99
          }
        },
        settings: %User.Settings{
          views_adult_content: true,
        }
      }
      |> Repo.preload(:categories)
      |> User.load_images
    end


    def featured_category_factory do
      %Category{
        name: "Featured",
        slug: "featured",
        cta_caption: nil,
        cta_href: nil,
        description: nil,
        is_sponsored: false,
        is_creator_type: false,
        level: "meta",
        order: 0,
        uses_page_promotionals: true,
        created_at: DateTime.utc_now,
        updated_at: DateTime.utc_now,
      } |> Category.load_images
    end

    def espionage_category_factory do
      %Category{
        id: 100_000,
        name: "Espionage",
        slug: "espionage",
        cta_caption: nil,
        cta_href: nil,
        description: "All things spying related",
        is_sponsored: false,
        is_creator_type: false,
        level: nil,
        order: 0,
        uses_page_promotionals: false,
        created_at: DateTime.utc_now,
        updated_at: DateTime.utc_now,
        promotionals: [],
      } |> Category.load_images
    end

    def lacross_category_factory do
      %Category{
        id: 100_001,
        name: "Lacross",
        slug: "lacross",
        cta_caption: nil,
        cta_href: nil,
        description: "All things lacross related",
        is_sponsored: false,
        is_creator_type: false,
        level: "Primary",
        order: 0,
        uses_page_promotionals: false,
        created_at: DateTime.utc_now,
        updated_at: DateTime.utc_now,
        tile_image: "ello-optimized-8bcedb76.jpg",
        tile_image_metadata: %{
          "large" => %{
            "size"   => 855_144,
            "type"   => "image/png",
            "width"  => 1_000,
            "height" => 1_000
          },
          "regular" => %{
            "size"   => 556_821,
            "type"   => "image/png",
            "width"  => 800,
            "height" => 800
          },
          "small" => %{
            "size"   => 126_225,
            "type"   => "image/png",
            "width"  => 360,
            "height" => 360
          },
        },
        promotionals: [Ello.Core.Factory.build(:promotional)]
      } |> Category.load_images
    end
  end
end
