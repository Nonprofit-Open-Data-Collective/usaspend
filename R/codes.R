## Code tables. These are reference data, not derived from any extract, so they
## are implemented now rather than stubbed.
##
## Two traps are encoded here deliberately:
##
##  1. Action-type codes COLLIDE across award families. "B" is CONTINUATION for
##     assistance and SUPPLEMENTAL AGREEMENT for contracts; "C" is REVISION for
##     assistance and FUNDING ONLY ACTION for contracts; "D" is ADJUSTMENT TO
##     COMPLETED AWARD for assistance and CHANGE ORDER for contracts. Any
##     classification that ignores the family is wrong.
##  2. The award_type / action_type DESCRIPTION strings are not stable. The
##     pilot extract carries both "DELIVERY ORDER" and "DO" for code C, and both
##     "PURCHASE ORDER" and "PO" for code B, in the same file. Always derive
##     labels from the code; never group on the description.

us_award_type_table <- function() {
  data.table::data.table(
    award_type_code = c("A", "B", "C", "D",
                        "IDV_A", "IDV_B", "IDV_B_A", "IDV_B_B", "IDV_B_C",
                        "IDV_C", "IDV_D", "IDV_E",
                        "02", "03", "04", "05", "06", "10", "07", "08", "09", "11"),
    award_type_label = c("BPA Call", "Purchase Order", "Delivery Order",
                         "Definitive Contract",
                         "GWAC", "IDC", "IDC Requirements",
                         "IDC Indefinite Quantity", "IDC Definite Quantity",
                         "FSS", "BOA", "BPA",
                         "Block Grant", "Formula Grant", "Project Grant",
                         "Cooperative Agreement", "Direct Payment for Specified Use",
                         "Direct Payment with Unrestricted Use", "Direct Loan",
                         "Guaranteed/Insured Loan", "Insurance",
                         "Other Financial Assistance"),
    award_family = c(rep("contract", 4), rep("idv", 8), rep("grant", 4),
                     rep("direct_payment", 2), rep("loan", 2), rep("other", 2)),
    award_group = c(rep("contract", 12), rep("assistance", 10))
  )
}

us_action_type_table <- function() {
  data.table::rbindlist(list(
    ## ---- assistance (FABS ActionType) ----
    data.table::data.table(
      award_group = "assistance",
      action_type_code = c("A", "B", "C", "D"),
      action_type_label = c("New", "Continuation", "Revision",
                            "Adjustment to Completed Award"),
      action_class = c("origination", "continuation", "revision", "adjustment")
    ),
    ## ---- contracts (FPDS reason for modification) ----
    data.table::data.table(
      award_group = "contract",
      action_type_code = c("A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
                           "L", "M", "N", "P", "R", "S", "T", "V", "W", "X"),
      action_type_label = c(
        "Additional Work (new agreement)", "Supplemental Agreement Within Scope",
        "Funding Only Action", "Change Order",
        "Terminate for Default", "Terminate for Convenience", "Exercise an Option",
        "Definitize Letter Contract", "Novation Agreement", "Close Out",
        "Definitize Change Order", "Other Administrative Action",
        "Legal Contract Cancellation", "Re-representation of Merger/Acquisition",
        "Re-representation", "Change PIID", "Transfer Action",
        "Vendor DUNS Change", "Vendor Address Change", "Terminate for Cause"),
      action_class = c(
        "origination", "revision", "funding_only", "revision",
        "termination", "termination", "continuation",
        "administrative", "administrative", "closeout",
        "administrative", "administrative", "termination", "administrative",
        "administrative", "administrative", "administrative",
        "administrative", "administrative", "termination")
    )
  ), use.names = TRUE)
}

#' Classify award type codes
#'
#' Maps a USAspending award type code to a stable label, an award family
#' (contract / idv / grant / direct_payment / loan / other) and the top-level
#' group (contract vs assistance).
#'
#' Contract IDV rows carry a blank award type code -- their type lives in
#' `idv_type_code` instead. Pass `idv_type_code` and it is used as a fallback.
#' Note that FPDS writes the IDV type as a bare letter (`"B"`, `"E"`), which
#' collides with the contract codes for Purchase Order and Definitive Contract,
#' so the fallback prefixes `IDV_` before looking the code up.
#'
#' @param award_type_code Character vector of award type codes.
#' @param idv_type_code Optional character vector of IDV type codes, used where
#'   `award_type_code` is missing. Accepted bare (`"B"`) or prefixed
#'   (`"IDV_B"`).
#' @return A `data.table` with one row per input and columns `award_type_code`,
#'   `award_type_label`, `award_family`, `award_group`.
#' @export
#' @examples
#' us_classify_award_type(c("04", "D", "IDV_B", NA))
us_classify_award_type <- function(award_type_code, idv_type_code = NULL) {
  code <- toupper(as_chr(award_type_code))
  if (!is.null(idv_type_code)) {
    idv <- toupper(as_chr(idv_type_code))
    ## FPDS stores this as a bare letter; "B" alone would read as Purchase Order
    bare <- !is.na(idv) & !startsWith(idv, "IDV_")
    idv[bare] <- paste0("IDV_", idv[bare])
    fill <- is.na(code) & !is.na(idv)
    code[fill] <- idv[fill]
  }
  tab <- us_award_type_table()
  out <- tab[data.table::data.table(award_type_code = code), on = "award_type_code"]
  out[is.na(award_family),
      c("award_type_label", "award_family", "award_group") :=
        list("Unknown", "unknown", "unknown")]
  out[]
}

#' Classify transaction action types
#'
#' Maps an action-type code to an economic class. Because the codes collide
#' across families, `award_group` is required, not optional.
#'
#' Classes:
#' \describe{
#'   \item{origination}{First obligation on a new award.}
#'   \item{continuation}{A funded continuation or exercised option -- new money
#'     on an existing award.}
#'   \item{revision}{An in-scope change that may add or remove money.}
#'   \item{funding_only}{An action whose sole purpose is to move money.}
#'   \item{adjustment}{A correction to an award already completed.}
#'   \item{termination}{Termination or cancellation; typically de-obligating.}
#'   \item{closeout}{Administrative closeout; typically zero-dollar.}
#'   \item{administrative}{Name, address, PIID and transfer changes; should be
#'     zero-dollar, and a non-zero one is worth flagging.}
#'   \item{unclassified}{Code missing or unrecognized. Base contract actions
#'     legitimately have a blank action type, so this is not by itself an error.}
#' }
#'
#' `action_class` describes *intent*, not sign. A continuation can carry a
#' negative obligation and a termination can carry zero. Never infer a
#' de-obligation from the class -- use the sign of the amount.
#'
#' @param action_type_code Character vector of action type codes.
#' @param award_group Character vector, `"contract"` or `"assistance"`, recycled
#'   to the length of `action_type_code`.
#' @return A `data.table` with `award_group`, `action_type_code`,
#'   `action_type_label`, `action_class`.
#' @export
#' @examples
#' # the same code means different things in the two families
#' us_classify_action(c("B", "B"), c("assistance", "contract"))
us_classify_action <- function(action_type_code, award_group) {
  code <- toupper(as_chr(action_type_code))
  grp  <- tolower(as_chr(award_group))
  grp  <- rep_len(grp, length(code))
  ## every family other than contracts uses the assistance code set
  grp[!is.na(grp) & grp != "contract"] <- "assistance"
  key <- data.table::data.table(award_group = grp, action_type_code = code)
  out <- us_action_type_table()[key, on = c("award_group", "action_type_code")]
  out[is.na(action_class),
      c("action_type_label", "action_class") := list("Unclassified", "unclassified")]
  out[]
}

#' Award type codes accepted by the download endpoints
#'
#' @param group One or more of `"contract"`, `"idv"`, `"grant"`,
#'   `"direct_payment"`, `"loan"`, `"other"`, `"assistance"` (grant + direct
#'   payment + loan + other), or `"all"`.
#' @return Character vector of award type codes.
#' @export
#' @examples
#' us_award_type_codes("grant")
#' length(us_award_type_codes("all"))
us_award_type_codes <- function(group = "all") {
  tab <- us_award_type_table()
  if (identical(group, "all")) return(tab$award_type_code)
  sel <- tab$award_family %in% group | tab$award_group %in% group
  if (!any(sel)) us_abort("No award types match {.val {group}}.")
  tab$award_type_code[sel]
}
