open Ipl_ast;;
open Format;;

let comma_separated ppf = 
  CCFormat.(list ~sep:(return ",@,") ppf)

let semi_separated ppf = 
  CCFormat.(list ~sep:(return ";@,") ppf)

let rec expr_pp ppf = 
  function
  | Paren x -> fprintf ppf "(%a)" expr_pp x
  | Or x | And x | Mul x | Add x | Eq x | Comp x | Implies x | Cont x 
    -> fprintf ppf "%a" binary_op_pp x
  | Not         x -> fprintf ppf "!(%a)" expr_pp x
  | Abs x -> fprintf ppf "abs(%a)" expr_pp x
  | FuncCall {name;args} -> fprintf ppf "%s(%a)" name CCFormat.(list ~sep:(return ",") expr_pp) args
  | UnaryMinus  x -> fprintf ppf    "(-(%a))" expr_pp x
  | Cond x -> fprintf ppf "if %a then %a else %a" expr_pp x.test expr_pp x.expr expr_pp x.orelse 
  | None   -> fprintf ppf "None"
  | Some x -> fprintf ppf "Some(%a)" expr_pp x
  | OptCase { value ; capture ; some ; none } ->
    fprintf ppf "case(%a){Some %s:%a}{Node: %a}" expr_pp value capture expr_pp some expr_pp none
  | ListLiteral  x -> fprintf ppf  "[@[<hov>%a@]]"  ( comma_separated expr_pp ) x
  |  SetLiteral  x -> fprintf ppf "{|@[<hov>%a@]|}" ( comma_separated expr_pp ) x
  |  MapLiteral  { elements ; default } -> 
    fprintf ppf  "<@[<hov>%a|default: %a@]>"  ( comma_separated map_element_pp) elements expr_pp default
  | Subset { left ; right } -> fprintf ppf "subset(%a,%a)" expr_pp left expr_pp right
  | Get    { left ; right } -> fprintf ppf "get(%a,%a)" expr_pp left expr_pp right
  |  BoolConst   x -> fprintf ppf ( if x then "true" else "false" )
  |   IntConst   x -> fprintf ppf "%d" x
  | FloatConst   x -> fprintf ppf "%f" x
  | StringRef    x -> fprintf ppf "\"%s\"" x
  | Field_vals   x -> fprintf ppf "{@[<hov>%a@]}" (semi_separated field_val_pp) x
  | ToInt        x -> fprintf ppf "toInt(%a)"       expr_pp x
  | ToFloat      x -> fprintf ppf "toFloat(%a)"     expr_pp x
  | IntOfString  x -> fprintf ppf "intOfString(%a)" expr_pp x
  | Present      x -> fprintf ppf "present(%a)"     expr_pp x
  | ValueRef     x -> fprintf ppf "%a" value_refs_pp x
and binary_op_pp ppf ( x : binary_op ) =
  fprintf ppf "(%a %s %a)" expr_pp x.left x.op expr_pp x.right
and map_element_pp ppf (x : map_element) =
  fprintf ppf "%a=%a" expr_pp x.map_key expr_pp x.map_value
and field_val_pp ppf (x : field_val) = 
  fprintf ppf "%s=%a" x.field expr_pp x.field_value
and value_ref_pp ppf ( s : value_ref ) =
  match s.index with 
  | None -> 
    fprintf ppf "%s" s.name 
  | Some i -> 
    fprintf ppf "%s[%a]" s.name expr_pp i
and value_refs_pp ppf (s:value_ref list) = 
  fprintf ppf "%a" (CCFormat.(list ~sep:(return ".") value_ref_pp)) s

let rec typedecl_pp ppf = function 
  | Set    x -> fprintf ppf "(%a) set"    typedecl_pp x
  | List   x -> fprintf ppf "(%a) list"   typedecl_pp x
  | Option x -> fprintf ppf "(%a) option" typedecl_pp x
  | Map    { map_key ; map_value } ->
    fprintf ppf "<%a,%a> map" typedecl_pp map_key typedecl_pp map_value
  | Simple s -> fprintf ppf "%s" s


let rec statement_pp ppf = function
  | Assign  { lvalue ; expr } ->
    fprintf ppf "%a = %a" value_refs_pp lvalue expr_pp expr
  | LetDecl { name ; ltype ; value } -> begin
      match ltype with 
      | Some ltype -> fprintf ppf "let %s : %a = %a" name typedecl_pp ltype expr_pp value
      | None       -> fprintf ppf "let %s = %a"      name expr_pp value
    end
  | If { test ; body ; orelse } -> begin
      match orelse with
      | [] -> 
        fprintf ppf "if(%a) then {@;<1 2>@[<v>%a@]@,}" 
          expr_pp test statement_list_pp body
      | _ ->
        fprintf ppf "if(%a) then {@;<1 2>@[<v>%a@]@,} else {@;<1 2>@[<v>%a@]@,}"
          expr_pp test statement_list_pp body statement_list_pp orelse
    end
  | Case { case ; none ; capture ; some } ->
    fprintf ppf "case ( %a ) { Some %s : %a } { None : %a }"
      expr_pp case capture statement_list_pp some statement_list_pp none
  | Insert { left ; right ; mapValue } -> begin
      match mapValue with 
      | Some mapValue ->
        fprintf ppf "insert( %a , %a=%a )"
          expr_pp left expr_pp right expr_pp mapValue
      | None ->
        fprintf ppf "insert( %a , %a )"
          expr_pp left expr_pp right 
    end
  | Remove { left ; right } ->
    fprintf ppf "remove(%a,%a)" expr_pp left expr_pp right
  | RangeIteration {var;from;to_;step;code} -> 
    fprintf ppf "for %a in (%a,%a,%a) {@;<1 2>@[<v>%a@]@,}" expr_pp var expr_pp from expr_pp to_ expr_pp step statement_list_pp code
  | EnumIteration {var;enum;code} ->
    fprintf ppf "for %a in %a {@;<1 2>@[<v>%a@]@,}" expr_pp var typedecl_pp enum statement_list_pp code
  | ReturnStatement {ret} ->  begin match ret with 
      | None -> fprintf ppf "return" 
      | Some x -> fprintf ppf "return %a" expr_pp x
    end
and statement_list_pp ppf lst =
  CCFormat.( list ~sep:(return "@,") statement_pp ppf lst)

let field_pp ppf (x : field) =
  fprintf ppf "%s %s: %a" x.name (match x.tag with | None -> "" | Some tag -> "\""^tag^"\"") typedecl_pp x.ftype 

let field_list_pp ppf ( x : field list ) =
  CCFormat.(list ~sep:(return "@,") field_pp) ppf x

let internal_field_pp ppf x = 
  match x.initial with 
  | Some initial ->
    fprintf ppf "%s : %a = %a;" x.name typedecl_pp x.ftype expr_pp initial
  | None ->
    fprintf ppf "%s : %a;" x.name typedecl_pp x.ftype 

let internal_field_list_pp ppf ( x : internal_field list ) =
  CCFormat.(list ~sep:(return "@,") internal_field_pp) ppf x

let validator_pp ppf x =
  fprintf ppf "validate {%a}" expr_pp x

let validator_list_pp ppf x =
  CCFormat.(list ~sep:(return "@,") validator_pp) ppf x

let case_list_pp ppf (x : (string * string option) list) =
  CCFormat.(list ~sep:(return "@,") 
              (fun fmt ((n,tg):string * string option) -> 
                 match tg with 
                 | None -> fprintf fmt "%s" n
                 | Some tg -> fprintf fmt "%s \"%s\"" n tg)) ppf x

let typedArg_pp ppf (name,ttype) =
  fprintf ppf "%s:%a" name  typedecl_pp ttype

let string_pp ppf name = 
  fprintf ppf "%s" name

let repeating_pp ppf repeating = 
  fprintf ppf "%s" (if repeating then "repeating" else "")

let outbound_pp ppf outbound = 
  fprintf ppf "%s" (if outbound then "outbound" else "")

let req_type_pp = function 
  | REQ -> "req"
  | OPT -> "opt"
  | IGN -> "ign"

let require_validity_pp ppf require_valids = 
  CCFormat.(list ~sep:(return "@,") (fun fmt expr -> 
      fprintf fmt "<1 2>@[<v>valid when %a@]" 
        expr_pp expr)) ppf require_valids

let require_pp ppf req = 
  fprintf ppf "%s %s %a" (req_type_pp req.optionality) req.name require_validity_pp req.validity

let require_list_pp ppf requires = 
  CCFormat.(list ~sep:(return "@,") (fun fmt req -> 
      fprintf fmt "%a" 
        require_pp req)) ppf requires

let model_statement_pp ppf =
  function
  | TypeAlias { name ; atype } ->
    fprintf ppf "alias %s: %a" name typedecl_pp atype 
  | Action { name ; fields ; validators } ->
    fprintf ppf "@[<v>action %s {@;<1 2>@[<v>%a@,%a@]@,}@]" 
      name field_list_pp fields validator_list_pp validators 
  | Record { name ; repeating; fields } ->
    fprintf ppf "@[<v>declare %a record %s {@;<1 2>@[<v>%a@]@,}@]" repeating_pp repeating name field_list_pp fields
  | Enum { name ; cases } ->
    fprintf ppf "@[<v>enum %s {@;<1 2>@[<v>%a@]@,}@]"   name case_list_pp cases
  | Scenario {name; events} -> 
    fprintf ppf "@[<v>messageFlows { %s {@;<1 2> @[<v>template [%a]@]@,}@]}" name CCFormat.(list ~sep:(return ",") string_pp) events
  | InternalDecl { name ; fields } ->
    fprintf ppf "@[<v>internal %s {@;<1 2> @[<v>%a@]@,}@]" name internal_field_list_pp fields   
  | Receive { action ; action_var ; body } ->
    fprintf ppf "@[<v>receive ( %s : %s ) {@;<1 2>@[<v>%a@]@,}@]" 
      action_var action statement_list_pp body
  | Function { name; args; returnType; body} ->
    fprintf ppf "@[<v>function %s(%a):%a {@;<1 2>@[<v>%a@]@,}@]" name CCFormat.(list ~sep:(return ",") typedArg_pp)
      args typedecl_pp returnType statement_list_pp body
  | MessageDeclaration {name; tag; fields} -> 
    fprintf ppf "@[<v>declare message %s \"%s\" {@;<1 2>@[<v>%a@]@,}@]" name tag field_list_pp fields
  | Message {name; outbound; requires;validators} -> 
    fprintf ppf "@[<v>%a message %s {@;<1 2>@[<v>%a@,%a@]@,}@]" 
      outbound_pp outbound name require_list_pp requires validator_list_pp validators 
  | RepeatingGroup {name; requires} -> 
    fprintf ppf "@[<v>repeatingGroup %s {@;<1 2>@[<v>%a@]@,}@]" 
      name require_list_pp requires

let program_pp ppf =
  fprintf ppf "@[<v>%a@]@." CCFormat.(list ~sep:(return "@,@,") model_statement_pp)