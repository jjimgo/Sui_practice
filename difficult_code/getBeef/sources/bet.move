
module getbeef::bet
{
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vec_map::{Self, VecMap};

    use getbeef::transfers;
    use getbeef::vec_maps;
    use getbeef::vectors;

    /* Errors */

    // create()
    const E_JUDGES_CANT_BE_PLAYERS: u64 = 0;
    const E_INVALID_NUMBER_OF_PLAYERS: u64 = 2;
    const E_INVALID_NUMBER_OF_JUDGES: u64 = 3;
    const E_DUPLICATE_PLAYERS: u64 = 4;
    const E_DUPLICATE_JUDGES: u64 = 5;
    const E_INVALID_QUORUM: u64 = 6;
    const E_INVALID_BET_SIZE: u64 = 7;

    // fund()
    const E_ONLY_PLAYERS_CAN_FUND: u64 = 100;
    const E_ALREADY_FUNDED: u64 = 101;
    const E_FUNDS_BELOW_BET_SIZE: u64 = 102;
    const E_NOT_IN_FUNDING_PHASE: u64 = 103;

    // vote()
    const E_NOT_IN_VOTING_PHASE: u64 = 200;
    const E_ONLY_JUDGES_CAN_VOTE: u64 = 201;
    const E_ALREADY_VOTED: u64 = 202; // (maybe: allow judges to update their vote)
    const E_PLAYER_NOT_FOUND: u64 = 203;

    // cancel()
    const E_CANCEL_BET_HAS_FUNDS: u64 = 300;
    const E_CANCEL_NOT_AUTHORIZED: u64 = 301;

    /* Settings */

    // create() constraints
    const MIN_PLAYERS: u64 = 2;
    const MAX_PLAYERS: u64 = 256;
    const MIN_JUDGES: u64 = 1;
    const MAX_JUDGES: u64 = 32;

    // Bet.phase possible values
    const PHASE_FUND: u8 = 0;
    const PHASE_VOTE: u8 = 1;
    const PHASE_SETTLED: u8 = 2;
    const PHASE_CANCELED: u8 = 3;
    const PHASE_STALEMATE: u8 = 4;

    struct Bet<phantom T> has key, store{
        id  :UID,
        phase : u8
        title : String,
        description : String,
        quorum : u64,
        size : u64,
        players : vector<address>,
        judges : vector<address>,
        votes : VecMap<address ,address>,
        funds : VecMap<address, Coin<T>>,
        most_votes : u64,
        winner :Option<address>
    }

    public fun phase<T>(bet: &Bet<T>): u8 {
        bet.phase
    }
    public fun title<T>(bet: &Bet<T>): &String {
        &bet.title
    }
    public fun description<T>(bet: &Bet<T>): &String {
        &bet.description
    }
    public fun quorum<T>(bet: &Bet<T>): u64 {
        bet.quorum
    }
    public fun size<T>(bet: &Bet<T>): u64 {
        bet.size
    }
    public fun players<T>(bet: &Bet<T>): &vector<address> {
        &bet.players
    }
    public fun judges<T>(bet: &Bet<T>): &vector<address> {
        &bet.judges
    }
    public fun votes<T>(bet: &Bet<T>): &VecMap<address, address> {
        &bet.votes
    }
    public fun funds<T>(bet: &Bet<T>): &VecMap<address, Coin<T>> {
        &bet.funds
    }
    public fun most_votes<T>(bet: &Bet<T>): u64 {
        bet.most_votes
    }
    public fun winner<T>(bet: &Bet<T>): &Option<address> {
        &bet.winner
    }

    public entry fun create<T> (
        title: vector<u8>,
        description: vector<u8>,
        quorum: u64,
        size: u64,
        players: vector<address>,
        judges: vector<address>,
        ctx: &mut TxContext
    ) {
        let player_len = vector::length(&players);
        let judge_len = vector::length(&judges);

        assert!( player_len >= MIN_PLAYERS && player_len <= MAX_PLAYERS, E_INVALID_NUMBER_OF_PLAYERS );
        assert!( judge_len >= MIN_JUDGES && judge_len <= MAX_JUDGES, E_INVALID_NUMBER_OF_JUDGES );

        assert!(!vectors::has_duplicates(&players), E_DUPLICATE_PLAYERS );
        assert!(!vectors::has_duplicates(&judges), E_DUPLICATE_JUDGES );
        assert!(!vectors::intersect(&players, &judges), E_JUDGES_CANT_BE_PLAYERS );

        assert!( (quorum > judge_len/2) && (quorum <= judge_len), E_INVALID_QUORUM );
        assert!( size > 0, E_INVALID_BET_SIZE );


        let bet = Bet<T> {
            id: object::new(ctx),
            phase: PHASE_FUND,
            title: string::utf8(title),
            description: string::utf8(description),
            quorum: quorum,
            size: size,
            players: players,
            judges: judges,
            votes: vec_map::empty(),
            funds: vec_map::empty(),
            most_votes: 0,
            winner: option::none(),
        };

        transfer::share_object(bet);
    }

    public entry fun fund<T>(
        bet: &mut Bet<T>,
        player_coin: Coin<T>,
        ctx: &mut TxContext
    ) {
        let player_addr = tx_context::sender(ctx);
        let coin_value : u64 = coin::value(&player_coin);

        assert!( bet.phase == PHASE_FUND, E_NOT_IN_FUNDING_PHASE );
        assert!( vector::contains(&bet.players, &player_addr), E_ONLY_PLAYERS_CAN_FUND ); // 
        assert!( !vec_map::contains(&bet.funds, &player_addr), E_ALREADY_FUNDED );
        assert!( coin_value >= bet.size, E_FUNDS_BELOW_BET_SIZE );

        //  funds : VecMap<address, Coin<T>>,


        let change = coin_value - bet.size;

        if ( change > 0 ) {
            transfer::transfer(
                coin::split(&mut player_coin, change, ctx),
                tx_context::sender(ctx)
            );
        };

        vec_map::insert(&mut bet.funds, player_addr, player_coin);

        // If all players have funded the Bet, advance to the voting phase
        if ( vec_map::size(&bet.funds) == vector::length(&bet.players) ) {
            bet.phase = PHASE_VOTE;
        };

    }


    public entry fun vote<T>(
        bet: &mut Bet<T>,
        player_addr: address,
        ctx: &mut TxContext)
    {
         let judge_addr = tx_context::sender(ctx);

        assert!( bet.phase == PHASE_VOTE, E_NOT_IN_VOTING_PHASE );
        assert!( vector::contains(&bet.judges, &judge_addr), E_ONLY_JUDGES_CAN_VOTE );
        assert!( !vec_map::contains(&bet.votes, &judge_addr), E_ALREADY_VOTED );
        assert!( vector::contains(&bet.players, &player_addr), E_PLAYER_NOT_FOUND );


    //  votes : VecMap<address ,address>,

        vec_map::insert(&mut bet.votes, judge_addr, player_addr);

        let player_vote_count = vec_maps::count_value(&bet.votes, &player_addr);

        if ( player_vote_count > bet.most_votes ) {
            bet.most_votes = player_vote_count;
        };

        if ( player_vote_count >= bet.quorum ) {
            transfers::send_all(&mut bet.funds, player_addr, ctx);
            bet.winner = option::some(player_addr);
            bet.phase = PHASE_SETTLED;
            return
        };

        // If it's no longer possible for any player to win, refund everyone and end the bet
        if ( is_stalemate(bet) ) {
            transfers::refund_all(&mut bet.funds);
            bet.phase = PHASE_STALEMATE;
            return
        };
    }

    public entry fun cancel<T>(bet: &mut Bet<T>, ctx: &mut TxContext) {
        assert!( bet.phase == PHASE_FUND, E_NOT_IN_FUNDING_PHASE );
        assert!( vec_map::is_empty(&bet.funds), E_CANCEL_BET_HAS_FUNDS );

        let sender = tx_context::sender(ctx);

        let is_player = vector::contains(&bet.players, &sender);
        let is_judge = vector::contains(&bet.judges, &sender);

        assert!( is_player || is_judge, E_CANCEL_NOT_AUTHORIZED );

        bet.phase = PHASE_CANCELED;
    }

    fun is_stalemate<T>(bet: &Bet<T>): bool {
        let number_of_judges = vector::length(&bet.judges);
        let votes_so_far = vec_map::size(&bet.votes);

        let votes_remaining = number_of_judges - votes_so_far;

        let distance_to_win = bet.quorum - bet.most_votes;

        return votes_remaining < distance_to_win
    }

}