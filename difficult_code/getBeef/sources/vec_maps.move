module getbeef::vec_maps
{
    use sui::vec_map::{Self, VecMap};

    /// Count how many times a value appears in a VecMap
    public fun count_value<K: copy, V>(
        haystack: &VecMap<K, V>,
        needle: &V): u64
    {
        let count = 0;
        let length = vec_map::size(haystack);


        let i = 0;

        while (i < length) {
            let (_, value) = vec_map::get_entry_by_idx(haystack, i);
            if ( value == needle ) {
                count = count + 1;
            };
            i = i + 1;
        };

        
        return count
    }

}