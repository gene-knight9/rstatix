#' @include utilities.R
NULL
#'Compute Summary Statistics
#'@description Compute summary statistics for one or multiple numeric variables.
#'@param data a data frame
#'@param ... (optional) One or more unquoted expressions (or variable names)
#'  separated by commas. Used to select a variable of interest. If no variable
#'  is specified, then the summary statistics of all numeric variables in the
#'  data frame is computed.
#'@param type type of summary statistics. Possible values include: \code{"full",
#'  "common", "robust",  "five_number", "mean_sd", "mean_se", "mean_ci",
#'  "median_iqr", "median_mad"}
#'@param show a character vector specifying the summary statistics you want to
#'  show. Example: \code{show = c("n", "mean", "sd")}. This is used to filter
#'  the output after computation.
#'@return A data frame containing descriptive statistics, such as: \itemize{
#'  \item \strong{n}: the number of individuals \item \strong{min}: minimum
#'  \item \strong{max}: maximum \item \strong{median}: median \item
#'  \strong{mean}: mean \item \strong{q1, q3}: the first and the third quartile,
#'  respectively. \item \strong{iqr}: interquartile range \item \strong{mad}:
#'  median absolute deviation (see ?MAD) \item \strong{sd}: standard deviation
#'  of the mean \item \strong{se}: standard error of the mean \item \strong{ci,
#'  ci.lower, ci.upper}: 95 percent confidence interval of the mean }
#' @examples
#' # Full summary statistics
#' data("ToothGrowth")
#' ToothGrowth %>% get_summary_stats(len)
#'
#' # Summary statistics of grouped data
#' # Show only common summary
#' ToothGrowth %>%
#'   group_by(dose, supp) %>%
#'   get_summary_stats(len, type = "common")
#'
#' # Robust summary statistics
#' ToothGrowth %>% get_summary_stats(len, type = "robust")
#'
#' # Five number summary statistics
#' ToothGrowth %>% get_summary_stats(len, type = "five_number")
#'
#' # Compute only mean and sd
#' ToothGrowth %>% get_summary_stats(len, type = "mean_sd")
#'
#' # Compute full summary statistics but show only mean, sd, median, iqr
#' ToothGrowth %>%
#'     get_summary_stats(len, show = c("mean", "sd", "median", "iqr"))
#'
#'@export
get_summary_stats <- function(
  data, ..., type = c("full", "common", "robust",  "five_number",
                      "mean_sd", "mean_se", "mean_ci", "median_iqr", "median_mad"),
  show = NULL
  ){
  type = match.arg(type)
  if(is_grouped_df(data)){
    results <- data %>%
      doo(get_summary_stats, ..., type = type, show = show)
    return(results)
  }
  data <- data %>% select_numeric_columns()
  vars <- data %>% get_selected_vars(...)
  n.vars <- length(vars)
  if(n.vars >= 1){
    data <- data %>% select(!!!syms(vars))
  }
  variable <- value <- NULL
  data <- data %>%
    gather(key = "variable", value = "value") %>%
    filter(!is.na(value)) %>%
    group_by(variable)
  results <- switch(
    type,
    common = common_summary(data),
    robust = robust_summary(data),
    five_number = five_number_summary(data),
    mean_sd = mean_sd(data),
    mean_se = mean_se(data),
    mean_ci = mean_ci(data),
    median_iqr = median_iqr(data),
    median_mad = median_mad(data),
    full_summary(data)
  ) %>%
    dplyr::mutate_if(is.numeric, round, digits = 3)

  if(!is.null(show)){
    show <- unique(c("variable", "n", show))
    results <- results %>% select(!!!syms(show))
  }

  results
}


full_summary <- function(data){
  confidence <- 0.95
  alpha <- 1 - confidence
  value <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      min = min(value, na.rm=TRUE),
      max = max(value, na.rm=TRUE),
      median = stats::median(value, na.rm=TRUE),
      q1 = stats::quantile(value, 0.25, na.rm = TRUE),
      q3 = stats::quantile(value, 0.75, na.rm = TRUE),
      iqr = stats::IQR(value, na.rm=TRUE),
      mad = stats::mad(value, na.rm=TRUE),
      mean = mean(value, na.rm = TRUE),
      sd = stats::sd(value, na.rm = TRUE)
    ) %>%
    mutate(
      se = .data$sd / sqrt(.data$n),
      ci = abs(stats::qt(alpha/2, .data$n-1)*.data$se),
      ci.lower = .data$mean - .data$ci,
      ci.upper = .data$mean + .data$ci
    )
}

common_summary <- function(data){
  confidence <- 0.95
  alpha <- 1 - confidence
  value <- ci <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      min = min(value, na.rm=TRUE),
      max = max(value, na.rm=TRUE),
      median = stats::median(value, na.rm=TRUE),
      iqr = stats::IQR(value, na.rm=TRUE),
      mean = mean(value, na.rm = TRUE),
      sd = stats::sd(value, na.rm = TRUE)
    ) %>%
    mutate(
      se = .data$sd / sqrt(.data$n),
      ci = abs(stats::qt(alpha/2, .data$n-1)*.data$se),
      ci.lower = .data$mean - .data$ci,
      ci.upper = .data$mean + .data$ci
    )%>%
    select(-ci)
}

robust_summary <- function(data){
  value <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      median = stats::median(value, na.rm=TRUE),
      iqr = stats::IQR(value, na.rm=TRUE)
    )
}


five_number_summary <- function(data){
  value  <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      min = min(value, na.rm=TRUE),
      max = max(value, na.rm=TRUE),
      q1 = stats::quantile(value, 0.25, na.rm = TRUE),
      median = stats::median(value, na.rm=TRUE),
      q3 = stats::quantile(value, 0.75, na.rm = TRUE)
    )
}

mean_sd <- function(data){
  value  <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      mean = mean(value, na.rm = TRUE),
      sd = stats::sd(value, na.rm = TRUE)
    )
}

mean_se <- function(data){
  value  <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      mean = mean(value, na.rm = TRUE),
      sd = stats::sd(value, na.rm = TRUE)
    ) %>%
    mutate(se = .data$sd / sqrt(.data$n))%>%
    select(-.data$sd)
}

mean_ci <- function(data){
  confidence <- 0.95
  alpha <- 1 - confidence
  value <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      mean = mean(value, na.rm = TRUE),
      sd = stats::sd(value, na.rm = TRUE)
    ) %>%
    mutate(
      se = .data$sd / sqrt(.data$n),
      ci = abs(stats::qt(alpha/2, .data$n-1)*.data$se)
    )%>%
    select(-.data$se, -.data$sd)
}

median_iqr <- function(data){
  value  <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      median = stats::median(value, na.rm=TRUE),
      iqr = stats::IQR(value, na.rm=TRUE)
    )
}

median_mad <- function(data){
  value  <- NULL
  data %>%
    dplyr::summarise(
      n = sum(!is.na(value)),
      median = stats::median(value, na.rm=TRUE),
      mad = stats::mad(value, na.rm=TRUE)
    )
}