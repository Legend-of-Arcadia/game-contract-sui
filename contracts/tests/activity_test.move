#[test_only]
module contracts::activity_test {
    use sui::test_scenario as ts;
    use contracts::game::{
    Self,
    GameCap,
    };
    use contracts::activity::{Self,ActivityConfig};
    use std::string::{Self};
    use loa::arca::ARCA;
    use sui::clock;
    use sui::coin::{Self, Coin};

    const GAME: address = @0x111;
    //const USER: address = @0x222;
    #[test]
    fun test_create_config_and_buy(){
        let scenario = ts::begin(GAME);
        game::init_for_test(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        let cap = ts::take_from_sender<GameCap>(&mut scenario);
        activity::create_config(&cap, 1688522400000, 1691200800000, 1000,
            19999, string::utf8(b"blue gacha"), string::utf8(b"blue gacha"),
            string::utf8(b"blue gacha"),string::utf8(b"blue gacha"), ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, GAME);
        let activity_config = ts::take_shared<ActivityConfig>(&mut scenario);
        activity::set_price<ARCA>(&cap, &mut activity_config, 1000);
        let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(5000, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);
        ts::next_tx(&mut scenario, GAME);
        let clock = ts::take_shared<clock::Clock>(&mut scenario);
        clock::increment_for_testing(&mut clock, 1688522400001);
        ts::next_tx(&mut scenario, GAME);
        activity::buy<ARCA>(&mut activity_config, fee, 5, &clock, ts::ctx(&mut scenario));

        ts::return_shared(clock);
        ts::return_to_sender<GameCap>(&scenario, cap);
        ts::return_shared(activity_config);

        ts::end(scenario);
    }

}
