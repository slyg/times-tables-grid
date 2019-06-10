port module Main exposing (Model)

import Browser
import Debug exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode as D exposing (Decoder, andThen, at)
import Json.Encode as E
import List exposing (concat, indexedMap, length, map, range)


type Level
    = Default
    | Known
    | Guessed
    | Unknown


type alias Cell =
    { x : Int, y : Int, level : Level }


type alias Model =
    List (List Cell)


type Msg
    = Noop
    | ChangeLevel Int Int
    | CachedGridLoaded String


init : Maybe Int -> ( Model, Cmd Msg )
init max =
    let
        maxRange =
            case max of
                Just n ->
                    n

                Nothing ->
                    10

        numbers =
            range 0 maxRange

        data =
            map (\x -> map (\y -> Cell x y Default) numbers) numbers
    in
    ( data, Cmd.none )


encodeLevel : Level -> E.Value
encodeLevel level =
    case level of
        Default ->
            E.string "Default"

        Known ->
            E.string "Known"

        Guessed ->
            E.string "Guessed"

        Unknown ->
            E.string "Unknown"


decodeLevel : String -> Decoder Level
decodeLevel level =
    case level of
        "Known" ->
            D.succeed Known

        "Guessed" ->
            D.succeed Guessed

        "Unknown" ->
            D.succeed Unknown

        "Default" ->
            D.succeed Default

        _ ->
            D.succeed Default


encodeCell : Cell -> E.Value
encodeCell cell =
    E.object
        [ ( "x", E.int cell.x )
        , ( "y", E.int cell.y )
        , ( "level", encodeLevel cell.level )
        ]


decodeCell : Decoder Cell
decodeCell =
    D.map3 Cell
        (at [ "x" ] D.int)
        (at [ "y" ] D.int)
        (at [ "level" ] D.string |> andThen decodeLevel)


decodeCols : Decoder (List Cell)
decodeCols =
    D.list decodeCell


encodeCols : List Cell -> E.Value
encodeCols =
    E.list encodeCell


encodeGrid : Model -> E.Value
encodeGrid =
    E.list encodeCols


decodeGrid : Decoder Model
decodeGrid =
    D.list decodeCols


updateLevel : Level -> Level
updateLevel level =
    case level of
        Default ->
            Unknown

        Unknown ->
            Guessed

        Guessed ->
            Known

        Known ->
            Default


updateCell : Int -> Int -> Cell -> Cell
updateCell x y cell =
    if (cell.x == x && cell.y == y) || (cell.x == y && cell.y == x) then
        Cell cell.x cell.y (updateLevel cell.level)

    else
        cell


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Noop ->
            ( model, Cmd.none )

        ChangeLevel a b ->
            let
                updateRow =
                    map (updateCell a b)

                updateModel =
                    map updateRow

                newModel =
                    updateModel model
            in
            ( newModel
            , cache (encodeGrid newModel)
            )

        CachedGridLoaded s ->
            let
                result =
                    Debug.log "" (D.decodeString decodeGrid s)

                newModel =
                    case result of
                        Ok r ->
                            r

                        Err _ ->
                            model
            in
            ( newModel, Cmd.none )


cellColor level =
    case level of
        Default ->
            "#ffffff"

        Unknown ->
            "#FEB3F2"

        Guessed ->
            "#cdefff"

        Known ->
            "#B6D19E"


view : Model -> Html Msg
view model =
    let
        cellStyle =
            [ style "padding" "0.5em"
            , style "text-align" "center"
            , style "border-radius" "2em"
            , style "width" "2em"
            , style "height" "2em"
            , style "transition" "background-color 0.2s"
            ]

        displayLabelCell val =
            let
                label =
                    if val == -1 then
                        ""

                    else
                        toString val
            in
            th
                (cellStyle
                    ++ [ style "background-color" "#eee"
                       ]
                )
                [ text label ]

        displayTopLabels m =
            tr [] (indexedMap (\i n -> displayLabelCell n) (range -1 (length m - 1)))

        displayCol cell =
            let
                { x, y, level } =
                    cell
            in
            td
                (cellStyle
                    ++ [ style "background-color" (cellColor level)
                       , style "cursor" "pointer"
                       , onClick (ChangeLevel x y)
                       ]
                )
                [ text (toString (x * y)) ]

        displayRow i cells =
            tr [] (displayLabelCell i :: map displayCol cells)

        displayLegend =
            let
                legends =
                    [ ( Unknown, "Unknown" )
                    , ( Guessed, "Guessed" )
                    , ( Known, "Known" )
                    ]

                template ( level, legend ) =
                    div
                        [ style "display" "flex"
                        , style "justify-content" "left"
                        , style "padding-bottom" "0.5em"
                        ]
                        [ div
                            (cellStyle
                                ++ [ style "background-color" (cellColor level)
                                   ]
                            )
                            []
                        , div
                            [ style "align-self" "center"
                            , style "padding-left" "0.5em"
                            ]
                            [ text legend ]
                        ]
            in
            map template legends
    in
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "font-family" "Helvetica"
        ]
        [ div
            [ style "display" "flex"
            , style "align-content" "center"
            , style "justify-content" "center"
            ]
            [ table [ style "margin" "1em" ]
                (displayTopLabels model
                    :: indexedMap displayRow model
                )
            , div
                [ style "margin" "1em"
                ]
                displayLegend
            ]
        ]


port cache : E.Value -> Cmd msg


port cacheLoaded : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    cacheLoaded (\s -> CachedGridLoaded s)


main : Program (Maybe Int) Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Time table grid"
                , body = [ view m ]
                }
        , subscriptions = subscriptions
        }
