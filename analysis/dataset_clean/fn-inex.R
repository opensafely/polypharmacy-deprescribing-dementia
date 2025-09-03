inex <- function(
    input,
    flow
    ) {
        ## Apply exclusion criteria
        print('Apply exclusion criteria')
        
        input <- subset(input, inex_bin_alive == TRUE) # Patients must be alive at index.
        flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Alive at index", nrow(input))
        print(flow[nrow(flow), ])

        input <- subset(input, inex_bin_has_dementia == TRUE) # Patients must have dementia diagnosis
        flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Diagnosed with dementia", nrow(input))
        print(flow[nrow(flow), ])

        input <- subset(input, cov_num_age > 64) # Patients must be age 65 or older
        flow[nrow(flow) + 1, ] <- c("Inclusion criteria: 65 years or older", nrow(input))
        print(flow[nrow(flow), ])

        input <- subset(input, inex_bin_long_term_antihypertensive_user == TRUE) # Patients must be long term antihypertensive user
        flow[nrow(flow) + 1, ] <- c("Inclusion criteria: Long term antihypertensive user", nrow(input))
        print(flow[nrow(flow), ])
        
        }
