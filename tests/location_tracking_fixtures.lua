return {
    valid = {
        {
            name = "world origin",
            value = { x = 0, y = 0, z = 0 },
            expected = { map = "Crater", x = 400, y = 400 },
        },
        {
            name = "Blood Kelp Trench Wreck landmark",
            value = { x = -1234.3, y = -349.7, z = -396.0 },
            expected = { map = "Crater", x = 153.14, y = 479.2 },
        },
        {
            name = "Bulb Zone West Wreck landmark",
            value = { x = 903.8, y = -220.3, z = 590.9 },
            expected = { map = "Crater", x = 580.76, y = 281.82 },
        },
        {
            name = "finite position outside the Crater image",
            value = { x = 5000, y = -50, z = -5000 },
            expected = { map = "Crater", x = 1400, y = 1400 },
        },
    },
    invalid = {
        {},
        { x = 0, y = 0 },
        { x = "0", y = 0, z = 0 },
        { x = 0 / 0, y = 0, z = 0 },
        { x = 0, y = math.huge, z = 0 },
        { x = 0, y = 0, z = -math.huge },
    },
}
