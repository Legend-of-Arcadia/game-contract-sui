#[test_only]
module loa_game::activity_test {
    use std::string::{Self};

    use sui::test_scenario as ts;
    use sui::clock;
    use sui::coin::{Self, Coin};

    use loa_game::game::{
    Self,
    GameCap,
    GameConfig
    };
    use loa_game::activity::{Self,ActivityConfig, ActivityProfits, ENeedVote, ECoinTypeNoExist};
    use loa::arca::ARCA;
    use multisig::multisig::{Self, MultiSignature};

    //use std::vector;
    //use std::debug;

    const GAME: address = @0x111;
    const USER: address = @0x222;
    #[test]
    fun test_create_config_and_buy(){
        let scenario = ts::begin(GAME);
        game::init_for_test(ts::ctx(&mut scenario));
        activity::init_for_test(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        let cap = ts::take_from_sender<GameCap>(&scenario);
        let game_config = ts::take_shared<GameConfig>(&scenario);
        activity::create_config(&cap, 1688522400000, 1691200800000, 1000,
            19999, string::utf8(b"blue gacha"), string::utf8(b"blue gacha"),
            string::utf8(b"blue gacha"),string::utf8(b"blue gacha"), &game_config,ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, GAME);
        {
            let activity_config = ts::take_shared<ActivityConfig>(&scenario);
            activity::set_price<ARCA>(&cap, &mut activity_config, 1000, &game_config);
            let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(5000, ts::ctx(&mut scenario));

            ts::next_tx(&mut scenario, GAME);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
            ts::next_tx(&mut scenario, GAME);
            let clock = ts::take_shared<clock::Clock>(&scenario);
            clock::increment_for_testing(&mut clock, 1688522400001);
            ts::next_tx(&mut scenario, GAME);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            activity::buy<ARCA>(&mut activity_config, fee, 5, &clock, &mut profits, ts::ctx(&mut scenario));

            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(activity_config);
            ts::return_shared(profits);
            ts::return_shared(game_config);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            let config = ts::take_shared<GameConfig>(&scenario);
            activity::withdraw_activity_profits_request<ARCA>(&config, &mut multi_signature, GAME,ts::ctx(&mut scenario));

            ts::return_shared(multi_signature);
            ts::return_shared(config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            let config = ts::take_shared<GameConfig>(&scenario);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
            let b = activity::withdraw_activity_profits_execute<ARCA>(&config, &mut multi_signature, 0, true, &mut profits,ts::ctx(&mut scenario));

            assert!(b, 1);

            ts::next_tx(&mut scenario, GAME);
            let coin = ts::take_from_address<Coin<ARCA>>(&scenario, GAME);
            //let x = coin::value(&coin);
            //debug::print(&coin::value<ARCA>(&coin));
            assert!(coin::value<ARCA>(&coin) == 5000, 1);

            ts::return_to_sender(&scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(profits);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ECoinTypeNoExist)]
    fun test_remove_price(){
        let scenario = ts::begin(GAME);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);
        game::init_for_test(ts::ctx(&mut scenario));
        activity::init_for_test(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        let cap = ts::take_from_sender<GameCap>(&scenario);
        let game_config = ts::take_shared<GameConfig>(&scenario);
        activity::create_config(&cap, 1688522400000, 1691200800000, 1000,
            19999, string::utf8(b"blue gacha"), string::utf8(b"blue gacha"),
            string::utf8(b"blue gacha"),string::utf8(b"blue gacha"), &game_config,ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, GAME);
        {
            let activity_config = ts::take_shared<ActivityConfig>(&scenario);
            activity::set_price<ARCA>(&cap, &mut activity_config, 1000, &game_config);
            ts::next_tx(&mut scenario, GAME);
            activity::remove_price<ARCA>(&cap, &mut activity_config, &game_config);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(activity_config);
            ts::return_shared(game_config);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(5000, ts::ctx(&mut scenario));
            let activity_config = ts::take_shared<ActivityConfig>(&scenario);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            let clock = ts::take_shared<clock::Clock>(&scenario);
            clock::increment_for_testing(&mut clock, 1688522400001);
            activity::buy<ARCA>(&mut activity_config, fee, 5, &clock, &mut profits, ts::ctx(&mut scenario));

            ts::return_shared(activity_config);
            ts::return_shared(profits);
            ts::return_shared(clock);
        };
        ts::end(scenario);
    }


    // #[test]
    // fun test_remove_config(){
    //     let scenario = ts::begin(GAME);
    //     let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(clock);
    //     game::init_for_test(ts::ctx(&mut scenario));
    //     activity::init_for_test(ts::ctx(&mut scenario));
    //
    //     ts::next_tx(&mut scenario, GAME);
    //     let cap = ts::take_from_sender<GameCap>(&scenario);
    //     activity::create_config(&cap, 1688522400000, 1691200800000, 1000,
    //         19999, string::utf8(b"blue gacha"), string::utf8(b"blue gacha"),
    //         string::utf8(b"blue gacha"),string::utf8(b"blue gacha"), ts::ctx(&mut scenario)
    //     );
    //
    //     ts::next_tx(&mut scenario, GAME);
    //     {
    //         let activity_config = ts::take_shared<ActivityConfig>(&scenario);
    //         //activity::set_price<ARCA>(&cap, &mut activity_config, 1000);
    //         ts::next_tx(&mut scenario, GAME);
    //         activity::remove_config(&cap, activity_config);
    //
    //         ts::return_to_sender<GameCap>(&scenario, cap);
    //         //ts::return_shared(activity_config);
    //     };
    //     ts::end(scenario);
    // }

    #[test]
    fun test_withraw_profits_by_multisig(){
        let scenario = ts::begin(GAME);
        game::init_for_test(ts::ctx(&mut scenario));
        activity::init_for_test(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        let cap = ts::take_from_sender<GameCap>(&scenario);
        let game_config = ts::take_shared<GameConfig>(&scenario);
        activity::create_config(&cap, 1688522400000, 1691200800000, 1000,
            19999, string::utf8(b"blue gacha"), string::utf8(b"blue gacha"),
            string::utf8(b"blue gacha"),string::utf8(b"blue gacha"), &game_config,ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, GAME);
        {
            let activity_config = ts::take_shared<ActivityConfig>(&scenario);
            activity::set_price<ARCA>(&cap, &mut activity_config, 1000, &game_config);
            let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(5000, ts::ctx(&mut scenario));

            ts::next_tx(&mut scenario, GAME);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
            ts::next_tx(&mut scenario, GAME);
            let clock = ts::take_shared<clock::Clock>(&scenario);
            clock::increment_for_testing(&mut clock, 1688522400001);
            ts::next_tx(&mut scenario, GAME);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            activity::buy<ARCA>(&mut activity_config, fee, 5, &clock, &mut profits, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, GAME);
            let amount = activity::get_activity_profits<ARCA>(&profits);
            assert!(amount == 5000, 1);

            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(activity_config);
            ts::return_shared(profits);
            ts::return_shared(game_config);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            multisig::create_multisig_setting_proposal(&mut multi_signature, vector[USER], vector[1], vector[], 2,ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, GAME);
            multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
            multisig::multisig_setting_execute(&mut multi_signature, 0, ts::ctx(&mut scenario));
            ts::return_shared(multi_signature);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            let config = ts::take_shared<GameConfig>(&scenario);
            activity::withdraw_activity_profits_request<ARCA>(&config, &mut multi_signature, GAME,ts::ctx(&mut scenario));

            ts::return_shared(multi_signature);
            ts::return_shared(config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            let config = ts::take_shared<GameConfig>(&scenario);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            multisig::vote(&mut multi_signature, 1, true, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER);
            multisig::vote(&mut multi_signature, 1, true, ts::ctx(&mut scenario));
            let b = activity::withdraw_activity_profits_execute<ARCA>(&config, &mut multi_signature, 1, true, &mut profits,ts::ctx(&mut scenario));

            assert!(b, 1);

            ts::next_tx(&mut scenario, GAME);
            let coin = ts::take_from_address<Coin<ARCA>>(&scenario, GAME);
            //let x = coin::value(&coin);
            //debug::print(&coin::value<ARCA>(&coin));
            assert!(coin::value<ARCA>(&coin) == 5000, 1);

            ts::return_to_sender(&scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(profits);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ENeedVote)]
    fun test_withraw_profits_by_multisig_fail(){
        let scenario = ts::begin(GAME);
        game::init_for_test(ts::ctx(&mut scenario));
        activity::init_for_test(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        let cap = ts::take_from_sender<GameCap>(&scenario);
        let game_config = ts::take_shared<GameConfig>(&scenario);
        activity::create_config(&cap, 1688522400000, 1691200800000, 1000,
            19999, string::utf8(b"blue gacha"), string::utf8(b"blue gacha"),
            string::utf8(b"blue gacha"),string::utf8(b"blue gacha"), &game_config,ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, GAME);
        {
            let activity_config = ts::take_shared<ActivityConfig>(&scenario);
            activity::set_price<ARCA>(&cap, &mut activity_config, 1000, &game_config);
            let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(5000, ts::ctx(&mut scenario));

            ts::next_tx(&mut scenario, GAME);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
            ts::next_tx(&mut scenario, GAME);
            let clock = ts::take_shared<clock::Clock>(&scenario);
            clock::increment_for_testing(&mut clock, 1688522400001);
            ts::next_tx(&mut scenario, GAME);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            activity::buy<ARCA>(&mut activity_config, fee, 5, &clock, &mut profits, ts::ctx(&mut scenario));

            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(activity_config);
            ts::return_shared(profits);
            ts::return_shared(game_config);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            multisig::create_multisig_setting_proposal(&mut multi_signature, vector[USER], vector[1], vector[], 2,ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, GAME);
            multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
            multisig::multisig_setting_execute(&mut multi_signature, 0, ts::ctx(&mut scenario));
            ts::return_shared(multi_signature);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            let config = ts::take_shared<GameConfig>(&scenario);
            activity::withdraw_activity_profits_request<ARCA>(&config, &mut multi_signature, GAME,ts::ctx(&mut scenario));

            ts::return_shared(multi_signature);
            ts::return_shared(config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&scenario);
            let config = ts::take_shared<GameConfig>(&scenario);
            let profits = ts::take_shared<ActivityProfits>(&scenario);
            multisig::vote(&mut multi_signature, 1, true, ts::ctx(&mut scenario));
            let b = activity::withdraw_activity_profits_execute<ARCA>(&config, &mut multi_signature, 1, true, &mut profits,ts::ctx(&mut scenario));

            assert!(b, 1);

            ts::next_tx(&mut scenario, GAME);
            let coin = ts::take_from_address<Coin<ARCA>>(&scenario, GAME);
            //let x = coin::value(&coin);
            //debug::print(&coin::value<ARCA>(&coin));
            assert!(coin::value<ARCA>(&coin) == 5000, 1);

            ts::return_to_sender(&scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(profits);
        };

        ts::end(scenario);
    }
}
